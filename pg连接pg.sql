--postgres_fdw方式
CREATE EXTENSION postgres_fdw;

CREATE SERVER pg_to_222
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host '10.110.39.222', port '5432', dbname 'postgis');
				
CREATE USER MAPPING FOR postgres
        SERVER pg_to_222
        OPTIONS (user 'postgres', password 'postgis');
				
CREATE FOREIGN TABLE foreign_tb_person (
	name varchar(20),
	age int
)SERVER pg_to_222 OPTIONS (schema_name 'public', table_name 'people');

insert into foreign_tb_person values ('李四',10);
insert into foreign_tb_person select * from people;

--dblink方式
--常规使用
create extension dblink;
select * from dblink('hostaddr=10.110.39.222 port=5432 dbname=postgis user=postgres password=postgis','select gid from zirancun') AS testTable ("gid" VARCHAR);
--解除连接
select dblink_disconnect('mycoon');
--如果不只是查询数据
select dblink_connect('mycoon','hostaddr=10.110.39.222 port=5432 dbname=postgis user=postgres password=postgis');
--执行BEGIN命令
select dblink_exec('mycoon', 'BEGIN');
select dblink_exec('mycoon', 'insert into people(name,age) values (''aaa'',10)');
select dblink_exec('mycoon', 'insert into people(name,age) values (''bbb'',20)');
--执行事务提交
select dblink_exec('mycoon', 'COMMIT');