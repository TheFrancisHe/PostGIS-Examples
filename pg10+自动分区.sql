create or replace function mdt_auto_partition(tablename varchar,partitionfield varchar,datetime varchar) 
returns boolean as $$ 
declare
ifexist boolean;
mintime varchar;
maxtime varchar;
partition_name text;
createpartition text;
createindex text;
begin
	if(tablename is null or tablename='')then 
		return false;
	end if;
	if(partitionfield is null or partitionfield='')then 
		return false;
	end if;
	if(datetime is null or datetime ='')then
			partition_name :=tablename||to_char(now(),'_yyyymmdd');
			mintime :=to_char(now(),'yyyy-mm-dd')||' 00:00:00';
			maxtime :=to_char((now() + interval '1 day'),'yyyy-mm-dd')||' 00:00:00';
	else
			partition_name :=tablename||to_char(datetime::timestamp,'_yyyymmdd');
			mintime :=to_char(datetime::timestamp,'yyyy-mm-dd')||' 00:00:00';
			maxtime :=to_char((datetime::timestamp + interval '1 day'),'yyyy-mm-dd')||' 00:00:00';
	end if;
	select count(*) into ifexist from pg_class where relname = partition_name;
	if(ifexist = false) then
		createpartition :='create table '||partition_name||' partition of '||tablename||' for values from ('''||mintime||''') to ('''||maxtime||''')';
		execute createpartition;
		createindex :='create index '||partition_name||'_index on '||partition_name||'('||partitionfield||')';
	end if;
	return true;
end $$ language plpgsql;


select mdt_auto_partition('tb_mdtimm_ingrid_cell_dd','time','2020-04-06');
select mdt_auto_partition('tb_mdtimm_ingrid_cell_dd','time','2020-04-07');
select mdt_auto_partition('tb_mdtimm_ingrid_cell_dd','time','2020-04-08');
select mdt_auto_partition('tb_mdtimm_ingrid_cell_dd','time','2020-04-09');
select mdt_auto_partition('tb_mdtimm_ingrid_cell_dd','time','2020-04-10');
