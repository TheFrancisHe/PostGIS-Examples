drop table famen_new;
drop table tiaoyaxiang_new;
drop table guanduan_new;

--drop table famen_new_temp;
--drop table tiaoyaxiang_new_temp;
--drop table guanduan_new_temp;
--create table famen_new_temp as select * from famen_new;
--create table tiaoyaxiang_new_temp as select * from tiaoyaxiang_new;
--create table guanduan_new_temp as select * from guanduan_new;

create table famen_new as select * from famen_new_temp;
create table tiaoyaxiang_new as select * from tiaoyaxiang_new_temp;
create table guanduan_new as select * from guanduan_new_temp;

--阀门
select st_astext(geom) as wkt,* from famen_new;
select AddGeometryColumn('public', 'famen_new', 'shape', 4326, 'POINT', 2);
update famen_new set shape = st_force2d(geom);
select DropGeometryColumn ('public','famen_new','geom');
alter table famen_new rename shape to geom;
create index famen_new_idx on famen_new using gist(geom);
--调压箱
select st_astext(geom) as wkt,* from tiaoyaxiang_new;
select AddGeometryColumn('public', 'tiaoyaxiang_new', 'shape', 4326, 'POINT', 2);
update tiaoyaxiang_new set shape = st_force2d(geom);
select DropGeometryColumn ('public','tiaoyaxiang_new','geom');
alter table tiaoyaxiang_new rename shape to geom;
create index tiaoyaxiang_new_idx on tiaoyaxiang_new using gist(geom);
--管段
select st_astext(geom) as wkt,* from guanduan_new;
select AddGeometryColumn('public', 'guanduan_new', 'shape', 4326, 'MULTILINESTRING', 2);
update guanduan_new set shape = st_force2d(geom);
select DropGeometryColumn ('public','guanduan_new','geom');
alter table guanduan_new rename shape to geom;
create index guanduan_new_idx on guanduan_new using gist(geom);

-----------------------------------------------------用开关关联管段，查询编号有误的开关------------------------------------------
drop table no_code_famen;
create table no_code_famen as
select m.id as gid from 
(select a.gid as id,b.gid from famen_new a
left join guanduan_new b on a.pscode=b.code) m where m.gid is null;

drop table no_code_tiaoyaxiang;
create table no_code_tiaoyaxiang as
select m.id as gid from 
(select a.gid as id,b.gid from tiaoyaxiang_new a
left join guanduan_new b on a.pscode=b.code) m where m.gid is null;

-----------------------------------------------------查询编号有误的开关所在管段--------------------------------------------------
update famen_new set pscode=m.code from
(select a.gid,b.code from famen_new a,
guanduan_new b where st_distance(b.geom,a.geom)<0.0000001 and a.gid in(select gid from no_code_famen)) m where famen_new.gid=m.gid;

update tiaoyaxiang_new set pscode=m.code from
(select a.gid,b.code from tiaoyaxiang_new a,
guanduan_new b where st_distance(b.geom,a.geom)<0.0000001 and a.gid in(select gid from no_code_tiaoyaxiang)) m where tiaoyaxiang_new.gid=m.gid;

-----------------------------------------------------给管段添加对应开关字段（爆管分析时效率更高）--------------------------------
alter table guanduan_new add column famen_code varchar(50);
alter table guanduan_new add column tiaoyaxiang_code varchar(50);

update guanduan_new set famen_code=m.code from
(select a.code,b.code as pscode from famen_new a
left join guanduan_new b on a.pscode=b.code)m where guanduan_new.code=m.pscode;

update guanduan_new set tiaoyaxiang_code=m.code from
(select a.code,b.code as pscode from tiaoyaxiang_new a
left join guanduan_new b on a.pscode=b.code)m where guanduan_new.code=m.pscode;
-----------------------------------------------------查询重复的管段,并删除gid小于中位数的管段--------------------------------------------------------------
drop table repeat_guanduan;
create table repeat_guanduan as 
select a.gid from guanduan_new a,
guanduan_new b where st_equals(a.geom, b.geom) and a.gid!=b.gid;

delete from guanduan_new where gid in (select gid from repeat_guanduan where gid <=
(select percentile_disc(0.5) within group ( order by gid ) from repeat_guanduan));

-----------------------------------------------------查找起始点相同的点，更新终点为几何的最后一个点--------------------------------------------------------
update guanduan_new set xend = st_x(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom)))),
yend = st_y(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom))))
where st_distance(ST_GeomFromText('POINT('||xend||' '||yend||')',4326),ST_StartPoint(ST_GeometryN(geom,1)))<0.0000000001;

update guanduan_new set xstart= st_x(ST_StartPoint(ST_GeometryN(geom,1)));
update guanduan_new set ystart= st_y(ST_StartPoint(ST_GeometryN(geom,1)));
update guanduan_new set xend= st_x(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom))));
update guanduan_new set yend= st_y(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom))));

--或者保留6位--
--update guanduan_new set xstart= CAST(xstart as DECIMAL(18,6));
--update guanduan_new set ystart= CAST(ystart as DECIMAL(18,6));
--update guanduan_new set xend= CAST(xend as DECIMAL(18,6));
--update guanduan_new set yend= CAST(yend as DECIMAL(18,6));

--管段有闭环的情况（关注第一个ring和最后一个ring，如果闭环，则取第二个或倒数第二个）
update guanduan_new set xstart=st_x(ST_StartPoint(ST_GeometryN(geom,2))),ystart=st_y(ST_StartPoint(ST_GeometryN(geom,2))) where gid in(
select gid from (
select n.gid,i as cid from guanduan_new n CROSS JOIN generate_series(1,ST_NumGeometries(n.geom)) i where st_astext(ST_StartPoint(ST_GeometryN(n.geom, i)))=st_astext(ST_EndPoint(ST_GeometryN(n.geom, i)))
) m where m.cid=1);

update guanduan_new set xend=st_x(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom)-1))),yend=st_y(ST_EndPoint(ST_GeometryN(geom,ST_NumGeometries(geom)-1))) where gid in(
select gid from (
select n.gid,i as cid,n.geom from guanduan_new n CROSS JOIN generate_series(1,ST_NumGeometries(n.geom)) i where st_astext(ST_StartPoint(ST_GeometryN(n.geom, i)))=st_astext(ST_EndPoint(ST_GeometryN(n.geom, i)))
) m where m.cid=ST_NumGeometries(m.geom));

delete from guanduan_new where xstart=xend and ystart=yend;

-----------------------------------------------------提取不重复的交点,并进行编号----------------------------------------------------------------------------
drop table guanduan_new_code;
create table guanduan_new_code as
select distinct x,y from
(select xstart as x,ystart as y from guanduan_new
union 
select xend as x,yend as y from guanduan_new) t;
alter table guanduan_new_code add code serial4;

select AddGeometryColumn('public', 'guanduan_new_code', 'geom', 4326, 'POINT', 2);
update guanduan_new_code set geom=ST_GeomFromText('POINT('||x||' '||y||')',4326);
create index guanduan_new_code_idx on guanduan_new_code using gist(geom);

-----------------------------------------------------对间距小于一定阈值的端点进行归一化编号----------------------------------------------------------------------------
drop table guanduan_new_code_new;
create table guanduan_new_code_new as 
select a.x,a.y,a.code,b.x as bx,b.y as by,b.code as bcode from guanduan_new_code a,guanduan_new_code b where ST_Transform(a.geom,3857)<->ST_Transform(b.geom,3857) <0.1 and a.code!=b.code;

delete from guanduan_new_code_new where code in (select code from guanduan_new_code_new where code <=
(select percentile_disc(0.5) within group ( order by code ) from guanduan_new_code_new));

update guanduan_new_code t
set code = m.code
from guanduan_new_code_new m
where t.code = m.bcode;
-----------------------------------------------------端点基础表---------------------------------------------------------------------------------------------

drop table guanduan_new_codeed;
create table guanduan_new_codeed as
select a.gid,b.code as start_code,c.code as end_code,a.xstart,a.ystart,a.xend,a.yend,a.geom from guanduan_new a
left join guanduan_new_code b on a.xstart=b.x and a.ystart=b.y
left join guanduan_new_code c on a.xend=c.x and a.yend=c.y;
-----------------------------------------------------查找起点不出现在终点列表的管段（表示应该打断该起点所相交的管段）-----------------------------------------
drop table guanduan_new_start_no_end;
create table guanduan_new_start_no_end as 
select * from guanduan_new_codeed where start_code not in (select end_code from guanduan_new_codeed);
-----------------------------------------------------查询两两相交管段(裁剪管段不和被裁剪管段收尾相交)---------------------------------------------------------
--ageom为裁剪管段，bgeom为被裁剪管段
drop table guanduan_new_un_break;
create table guanduan_new_un_break as 
select a.gid as aid,a.geom as ageom,b.gid as bid,b.geom as bgeom from
guanduan_new_start_no_end a
left join guanduan_new b on ST_Intersects(a.geom,b.geom)='t' where a.gid != b.gid and a.xstart != b.xend and a.ystart!= b.xend and a.xend != b.xstart and a.yend!= b.ystart;

-----------------------------------------------------相交处为点,如果是线则打断时忽略（应该打断）--------------------------------------------------------------
drop table guanduan_new_need_break;
create table guanduan_new_need_break as 
select aid,bid,ageom,bgeom from guanduan_new_un_break where ST_Dimension(ST_Intersection(bgeom, ageom))=0
and ST_NumGeometries(ST_Intersection(bgeom, ageom))=1 ;

-----------------------------------------------------查询两两管段相交但是都不在管段的端点的管段（打断时忽略）--------------------------------------------------
drop table guanduan_new_needed_break;
create table guanduan_new_needed_break as 
select aid,bid,ageom,bgeom from guanduan_new_need_break where ST_NumGeometries(ST_Split(bgeom, ageom))<=2;

--select aid,bid,ageom,bgeom from guanduan_new_need_break where st_distance(bgeom, ageom)<=0.0000001;
-----------------------------------------------------打断管段--------------------------------------------------------------------------------------------------
drop table guanduan_new_break_breaked;
create table guanduan_new_break_breaked as 
select * from 
(select a.aid,a.bid,
c.start_code,
b.start_code as middle_code,--交点编码
c.end_code,
ST_GeometryN(ST_Split(a.bgeom, a.ageom),1) as b_1_geom,--裁剪的管段一半
ST_GeometryN(ST_Split(a.bgeom, a.ageom),2) as b_2_geom,
ST_Intersection(a.bgeom, a.ageom) as geom, --交点
st_distance(ST_Transform(ST_Intersection(a.bgeom, a.ageom),3857),ST_Transform(ST_StartPoint(ST_GeometryN(bgeom,1)),3857)) as distance, -- 交点到被裁剪管段的距离，进行排序
st_distance(ST_Transform(ST_Intersection(a.bgeom, a.ageom),3857),ST_Transform(ST_StartPoint(ST_GeometryN(ageom,1)),3857)) as dis --交点到裁剪管点起点的距离，大于0.0000001就不应该裁剪（穿越）
from guanduan_new_needed_break a
left join guanduan_new_codeed b on a.aid=b.gid
left join guanduan_new_codeed c on a.bid=c.gid
) m 
where m.b_2_geom is not null;

--删除穿越但是进行 了裁剪的管段
delete from guanduan_new_break_breaked where dis>0.1;

-----------------------------------------------------多点打断管段-----------------------------------------------------------------------------------------------
drop table breaked_guanduan;
create table breaked_guanduan as
select n.gid,i as cid,ST_GeometryN(n.geom, i) as geom from (
select b.gid,ST_Split(b.geom,st_buffer(a.geom,0.00000001)) as geom from 
(select bid,ST_Union(geom) as geom from guanduan_new_break_breaked group by bid ) a,
guanduan_new b where a.bid=b.gid) n CROSS JOIN generate_series(1,ST_NumGeometries(n.geom)) i where st_length(ST_GeometryN(n.geom, i))>0.00000005;

create index breaked_guanduan_idx on breaked_guanduan using gist(geom);

drop table guanduan_break_code;
create table guanduan_break_code as
select a.gid,a.cid,b.code as start_code,c.code as end_code,a.geom from breaked_guanduan a
left join guanduan_new_code b on st_distance(ST_Transform(b.geom,3857),ST_Transform(ST_StartPoint(ST_GeometryN(a.geom,1)),3857))<0.1
left join guanduan_new_code c on st_distance(ST_Transform(c.geom,3857),ST_Transform(ST_EndPoint(ST_GeometryN(a.geom,ST_NumGeometries(a.geom))),3857))<0.1;

-----------------------------------------------------合并生成新的管段-----------------------------------------------------------------------------------------------
drop table new_guanduan;
create table new_guanduan as
select gid,null as cid,start_code,end_code,geom from guanduan_new_codeed where gid not in(select gid from guanduan_break_code)
union all
select gid,cid,start_code,end_code,geom from guanduan_break_code;

-----------------------------------------------------继承原有的开关与管段关系，被裁减的重新计算所在管段--------------------------------------------------------------
drop table guanduan_on_off;
create table guanduan_on_off as
select gid,famen_code,tiaoyaxiang_code from guanduan_new where gid not in(select gid from guanduan_break_code);

--规避已经绑定了管段的开关
drop table guanduan_on_off_famen;
create table guanduan_on_off_famen as
select gid,cid,code from (
select ROW_NUMBER() OVER (partition BY code ORDER BY distance) rowId,* from 
(select b.gid,b.cid,a.code,a.geom<->b.geom as distance from new_guanduan b,
famen_new a
where a.geom<->b.geom < 0.000000001 and b.gid in(select gid from guanduan_break_code)  and a.code not in(select distinct famen_code from guanduan_on_off where famen_code is not null)
order by a.geom<->b.geom) t) m where m.rowId=1;

drop table guanduan_on_off_tiaoyaxiang;
create table guanduan_on_off_tiaoyaxiang as
select gid,cid,code from (
select ROW_NUMBER() OVER (partition BY code ORDER BY distance) rowId,* from 
(select b.gid,b.cid,a.code,a.geom<->b.geom as distance from new_guanduan b,
tiaoyaxiang_new a
where a.geom<->b.geom < 0.000000001 and b.gid in(select gid from guanduan_break_code)  and a.code not in(select distinct tiaoyaxiang_code from guanduan_on_off where tiaoyaxiang_code is not null)
order by a.geom<->b.geom) t) m where m.rowId=1;

-----------------------------------------------------生成管段网络数据集---------------------------------------------------------------------------------------------
drop table guanduan_network;
create table guanduan_network as
select a.*,c.name,c.code,b.famen_code,b.tiaoyaxiang_code from new_guanduan a
left join guanduan_on_off b on a.gid=b.gid
left join guanduan_new c on a.gid=c.gid  where a.cid is null
union all
select a.*,d.name,d.code,b.code as famen_code,c.code as tiaoyaxiang_code from new_guanduan a
left join guanduan_on_off_famen b on a.gid=b.gid and a.cid=b.cid
left join guanduan_on_off_tiaoyaxiang c on a.gid=c.gid and a.cid=c.cid
left join guanduan_new d on a.gid=d.gid  where a.cid is not null;

alter table guanduan_network add id serial4;

create index start_index on guanduan_network(start_code);
create index end_index on guanduan_network(end_code);

-----------------------------------------------------爆管分析存储过程-----------------------------------------------------------------------------------------------
drop function queryPipeline(lon float,lat float,f_arr varchar[],t_arr varchar[]) 

CREATE OR REPLACE FUNCTION queryPipeline(lon float,lat float,f_arr varchar[],t_arr varchar[]) 
returns table(
	id int,
	famen_code varchar,
	tiaoyaxiang_code varchar
) AS $idx$ 
DECLARE
isNode int= 0;
s_code int;
r record;
w record;
break_length float =0;
onoff_length float =0;
BEGIN
	select * into r from guanduan_network where st_transform(geom, 3857)<->st_transform(st_geomfromtext('POINT('||lon||' '||lat||')',4326), 3857)<15 order by geom<->st_geomfromtext('POINT('||lon||' '||lat||')',4326) limit 1;
	if r is null then --如果离管道太远，默认为没有爆管点
		return next;
	else
		if (r.famen_code is not null and array_position(f_arr, r.famen_code) is null) or (r.tiaoyaxiang_code is not null and array_position(t_arr, r.tiaoyaxiang_code) is null) then --如果当前管段就有开关
			select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, st_geomfromtext('POINT('||lon||' '||lat||')',4326)),0.0000001)),1)) into break_length;
			if r.famen_code is not null then
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from famen_new where code=r.famen_code;
			else
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from tiaoyaxiang_new where code=r.tiaoyaxiang_code;
			end if;
			if break_length>onoff_length then --第一个管段，爆管点位于开关下游,返回当前管段就行
				isNode = 1;
				id:=r.id;
				famen_code:=r.famen_code;
				tiaoyaxiang_code:=r.tiaoyaxiang_code;
				return next;
			else
				s_code = r.start_code;--当前管段的起点作为上一管段的终点
				id:=r.id;
				famen_code:=null;
				tiaoyaxiang_code:=null;
				return next;
				while isNode=0 loop
					select * into w from guanduan_network where end_code = s_code;--查询上一管段
					if w is null then --已经查询到最后一级
						isNode = 1;
						id:=w.id;
						famen_code:=w.famen_code;
						tiaoyaxiang_code:=w.tiaoyaxiang_code;
						return next;
					else
						if w.famen_code is null and w.tiaoyaxiang_code is null then --如果当前管段没有开关，则记录起点，循环到上一级管段
							s_code = w.start_code;
							id:=w.id;
							famen_code:=w.famen_code;
							tiaoyaxiang_code:=w.tiaoyaxiang_code;
							return next;
						else
							if array_position(f_arr, w.famen_code) is not null or array_position(t_arr, w.tiaoyaxiang_code) is  not null then
								s_code = w.start_code;
								id:=w.id;
								famen_code:=w.famen_code;
								tiaoyaxiang_code:=w.tiaoyaxiang_code;
								return next;
							else
								isNode = 1;
								id:=w.id;
								famen_code:=w.famen_code;
								tiaoyaxiang_code:=w.tiaoyaxiang_code;
								return next;
							end if;
						end if;
					end if;
				end loop;
			end if;
		else
			s_code = r.start_code;--当前管段的起点作为上一管段的终点
			id:=r.id;
			famen_code:=r.famen_code;
			tiaoyaxiang_code:=r.tiaoyaxiang_code;
			return next;
			while isNode=0 loop
				select * into w from guanduan_network where end_code = s_code;--查询上一管段
				if w is null then --已经查询到最后一级
					isNode = 1;
					id:=w.id;
					famen_code:=w.famen_code;
					tiaoyaxiang_code:=w.tiaoyaxiang_code;
					return next;
				else
					if w.famen_code is null and w.tiaoyaxiang_code is null then --如果当前管段没有开关，则记录起点，循环到上一级管段
						s_code = w.start_code;
						id:=w.id;
						famen_code:=w.famen_code;
						tiaoyaxiang_code:=w.tiaoyaxiang_code;
						return next;
					else
						if array_position(f_arr, w.famen_code) is not null or array_position(t_arr, w.tiaoyaxiang_code) is  not null then
							s_code = w.start_code;
							id:=w.id;
							famen_code:=w.famen_code;
							tiaoyaxiang_code:=w.tiaoyaxiang_code;
							return next;
						else
							isNode = 1;
							id:=w.id;
							famen_code:=w.famen_code;
							tiaoyaxiang_code:=w.tiaoyaxiang_code;
							return next;
						end if;
					end if;
				end if;
			end loop;
		end if;
	end if;
END;
$idx$ LANGUAGE plpgsql;

--爆管分析
select a.gid,a.cid,a.id,a.code,a.name,d.famen_code,d.tiaoyaxiang_code,st_astext(a.geom) as wkt,st_astext(b.geom) as famen_wkt,st_astext(c.geom) as tiaoyaxiang_wkt from queryPipeline(103.55215025741097, 29.436887372432007,null,null) d left join famen_new b on d.famen_code=b.code left join tiaoyaxiang_new c on d.tiaoyaxiang_code=c.code left join guanduan_network a on a.id=d.id where d.id is not null;

-----------------------------------------------------爆管分析下游受影响阀门存储过程---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION queryDownPipeline(lon float,lat float) 
returns table(
	id int,
	famen_code varchar,
	tiaoyaxiang_code varchar
) 
AS $idx$ DECLARE
e_code int[];--当前层级终点集合
te_code int[];--临时存储终点集合
r record;
w record;
break_length float =0;
onoff_length float =0;
idx int[];--用于对数组赋值，达到清空数组的效果
BEGIN
	select * into r from guanduan_network where st_transform(geom, 3857)<->st_transform(st_geomfromtext('POINT('||lon||' '||lat||')',4326), 3857)<15 order by geom<->st_geomfromtext('POINT('||lon||' '||lat||')',4326) limit 1;
	if r is null then --如果离管道太远，默认为没有爆管点
		return next;
	else
		if (r.famen_code is not null) or (r.tiaoyaxiang_code is not null) then --如果当前管段就有开关
			select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, st_geomfromtext('POINT('||lon||' '||lat||')',4326)),0.0000001)),1)) into break_length;
			if r.famen_code is not null then
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from famen_new where code=r.famen_code;
			else
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from tiaoyaxiang_new where code=r.tiaoyaxiang_code;
			end if;
			if break_length<onoff_length then --第一个管段，爆管点位于开关上游
				id:=r.id;
				famen_code:=r.famen_code;
				tiaoyaxiang_code:=r.tiaoyaxiang_code;
				return next;
				select array_append(e_code,r.end_code) into e_code;--当前管段的终点作为下一管段的起点
				while array_length(e_code,1) > 0  
				loop
					te_code = idx;
					for w in
						select * from guanduan_network where start_code = any(e_code) --查询下一管段
					loop
						id:=w.id;
						famen_code:=w.famen_code;
						tiaoyaxiang_code:=w.tiaoyaxiang_code;
						select array_append(te_code,w.end_code) into te_code;
						return next;
					end loop;
					e_code = te_code;
				end loop;
			else
				id:=r.id;
				famen_code:=null;
				tiaoyaxiang_code:=null;
				return next;
				select array_append(e_code,r.end_code) into e_code;--当前管段的终点作为下一管段的起点
				while array_length(e_code,1) > 0  
				loop
					te_code = idx;
					for w in
						select * from guanduan_network where start_code = any(e_code) --查询下一管段
					loop
						id:=w.id;
						famen_code:=w.famen_code;
						tiaoyaxiang_code:=w.tiaoyaxiang_code;
						select array_append(te_code,w.end_code) into te_code;
						return next;
					end loop;
					e_code = te_code;
				end loop;
			end if;
		else
			id:=r.id;
			famen_code:=r.famen_code;
			tiaoyaxiang_code:=r.tiaoyaxiang_code;
			return next;
			select array_append(e_code,r.end_code) into e_code;--当前管段的终点作为下一管段的起点
			while array_length(e_code,1) > 0  
			loop
				te_code = idx;
				for w in
					select * from guanduan_network where start_code = any(e_code) --查询下一管段
				loop
					id:=w.id;
					famen_code:=w.famen_code;
					tiaoyaxiang_code:=w.tiaoyaxiang_code;
					select array_append(te_code,w.end_code) into te_code;
					return next;
				end loop;
				e_code = te_code;
			end loop;
		end if;
	end if;
END;
$idx$ LANGUAGE plpgsql;

--下游分析
select gid,cid,code,name,famen_code,id,tiaoyaxiang_code,st_astext(geom) as wkt from guanduan_network where cast(id as int) = any(array(select queryDownPipeline(103.55461627535306, 29.438828789314563)));





-----------------------------------------------------分析爆管点所在管段位置（同一管段，开关和爆管点谁是上游）---------------------------------------------------------------------------------
drop function queryIsUpOrDown(lon float,lat float);

CREATE OR REPLACE FUNCTION queryIsUpOrDown(lon float,lat float) 
returns varchar AS $idx$ DECLARE
r record;
v varchar='';
break_length float =0;
onoff_length float =0;
BEGIN
	select * into r from guanduan_network where st_transform(geom, 3857)<->st_transform(st_geomfromtext('POINT('||lon||' '||lat||')',4326), 3857)<15 order by geom<->st_geomfromtext('POINT('||lon||' '||lat||')',4326) limit 1;
	if r is null then --如果当前管段就有开关
		return v;
	else
		if (r.famen_code is not null) or (r.tiaoyaxiang_code is not null) then --如果当前管段就有开关
			select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, st_geomfromtext('POINT('||lon||' '||lat||')',4326)),0.0000001)),1)) into break_length;
			if r.famen_code is not null then
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from famen_new where code=r.famen_code;
			else
				select st_length(st_geometryn(st_split(r.geom,st_buffer(st_closestpoint(r.geom, geom),0.0000001)),1)) into onoff_length from tiaoyaxiang_new where code=r.tiaoyaxiang_code;
			end if;
			if break_length > onoff_length then
				if r.famen_code is not null then
					v=r.famen_code;
				else
					v=r.tiaoyaxiang_code;
				end if;
			end if;
		end if;
	end if;
	return v;
END
$idx$ LANGUAGE plpgsql;

select queryIsUpOrDown(103.55461627535306, 29.438828789314563);


