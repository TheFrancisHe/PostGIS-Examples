create table road as
select road_id,croadclass,nroadclass,width,ST_Transform(geom,3857) as geom from road_temp;

select croadclass,nroadclass,width from road where width is not null;
select distinct croadclass,nroadclass from road order by nroadclass;
--计算线段长度
create table road_length as 
select road_id,ceil(st_length(geom)/20) as num,geom from road;

--线段等距离分段
create table road_block as
select road_id,ST_LineSubstring(geom,(1/num)*(n-1),(1/num)*n) as geom from road_length CROSS JOIN generate_series (1,cast(num as integer)) n;
--添加唯一id
ALTER TABLE road_block ADD id serial8;
--缓冲区
create table road_buffer as
select id,road_id,ST_Buffer(geom, 10, 'endcap=flat join=round') as geom from road_block;

--创建索引
create index road_buffer_geom_idx on road_buffer using gist(geom);