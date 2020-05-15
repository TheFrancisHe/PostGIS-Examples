--9.X版本通过触发器得方式创建分区，插入效率很低
CREATE OR REPLACE FUNCTION auto_insert_into_tbl_partition () RETURNS TRIGGER AS $BODY$ DECLARE
	time_column_name TEXT;-- 父表中用于分区的时间字段的名称[必须首先初始化!!]
curMM VARCHAR ( 10 );-- 'YYYY-MM-DD'字串,用做分区子表的后缀
isExist BOOLEAN;-- 分区子表,是否已存在
startTime TEXT;
endTime TEXT;
strSQL TEXT;
BEGIN-- 调用前,必须首先初始化(时间字段名):time_column_name [直接从调用参数中获取!!]
	time_column_name := TG_ARGV [ 0 ];
-- 判断对应分区表 是否已经存在?
	EXECUTE'SELECT $1.' || time_column_name INTO strSQL USING NEW;
	curMM := to_char( strSQL :: TIMESTAMP, 'YYYYMMDD' );
	SELECT COUNT
		( * ) INTO isExist 
	FROM
		pg_class 
	WHERE
		relname = ( TG_RELNAME || '_' || curMM );
-- 若不存在, 则插入前需 先创建子分区
	IF
		( isExist = FALSE ) THEN-- 创建子分区表
			startTime :=  to_char((curMM || ' 00:00:00'):: TIMESTAMP, 'YYYY-MM-DD HH24:MI:SS' );
		endTime := to_char( startTime :: TIMESTAMP + INTERVAL '1 day', 'YYYY-MM-DD HH24:MI:SS' );
		strSQL := 'CREATE TABLE IF NOT EXISTS atu_road.' || TG_RELNAME || '_' || curMM || ' ( CHECK(' || time_column_name || '>=''' || startTime || ''' AND ' || time_column_name || '< ''' || endTime || ''' )
		) INHERITS (atu_road.' || TG_RELNAME || ') ;';
		EXECUTE strSQL;
-- 创建索引
		--strSQL := 'CREATE INDEX ' || TG_RELNAME || '_' || curMM || '_INDEX_' || time_column_name || ' ON atu_road.' || TG_RELNAME || '_' || curMM || ' (' || --time_column_name || ');';
		--EXECUTE strSQL;
		
	END IF;
-- 插入数据到子分区!
	strSQL := 'INSERT INTO atu_road.' || TG_RELNAME || '_' || curMM || ' SELECT $1.*';
	EXECUTE strSQL USING NEW;
	RETURN NULL;
	
END $BODY$ LANGUAGE plpgsql;

--使用
DROP TRIGGER tb_mdtimm_ingrid_cell_dd_trigger ON tb_mdtimm_ingrid_cell_dd;
CREATE TRIGGER tb_mdtimm_ingrid_cell_dd_trigger BEFORE INSERT ON tb_mdtimm_ingrid_cell_dd FOR EACH ROW
EXECUTE PROCEDURE auto_insert_into_tbl_partition ( 'time' );