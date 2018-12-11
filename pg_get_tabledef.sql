--
-- pg_get_tabledef()
-- Get Table DDL statement.
--
create or replace function pg_get_tabledef(in schema_name text, in table_name text)
returns text as $$
declare res text := '-- テーブルが見つかりません';
declare table_check integer;
declare rec record;
declare idx_str text := '';
declare com_str text := '';
declare comma_flg boolean := false;
begin

  -- スキーマNULLチェック
  if schema_name is null then
    select current_schema() into schema_name;
  end if;

  -- 引数を小文字に変換
  -- (PostgreSQLは定義を小文字で管理しているため)
  schema_name := lower(schema_name);
  table_name := lower(table_name);

  -- テーブル有無チェック
  select
    1 into table_check
  from pg_class pc 
  inner join pg_namespace pn 
    on pn.oid = pc.relnamespace 
  where
    pn.nspname = schema_name
    and pc.relname = table_name;

  if table_check is not null then

    -- 定義作成
    res := 'DROP TABLE IF EXISTS ' || schema_name || '.' || table_name || ' CASCADE;' || chr(10);
    res := res || 'CREATE TABLE ' || schema_name || '.' || table_name || ' (' || chr(10);

    for rec in
      select
        pa.attnum
        , pa.attname
        , pg_catalog.format_type(pa.atttypid, pa.atttypmod) || case 
          when pa.attnotnull 
            then ' not null' 
            else ''
          end || ' ' || coalesce( 
          ( 
            select
              substring( 
                pg_catalog.pg_get_expr(pd.adbin, pd.adrelid) for 128
              ) 
            from
              pg_catalog.pg_attrdef pd 
            where
              pd.adrelid = pa.attrelid 
              and pd.adnum = pa.attnum 
              and pa.atthasdef
          ) 
          , ''
        ) as format
      from pg_catalog.pg_attribute pa 
      inner join pg_catalog.pg_class pc 
        on pa.attrelid = pc.oid 
      inner join pg_catalog.pg_namespace pn 
        on pn.oid = pc.relnamespace 
      where
        pn.nspname = schema_name 
        and pc.relname = table_name 
        and pa.attnum > 0
      order by attnum
    loop

      -- カラム部分作成
      if comma_flg then
        res := res || '  , ';
      else
        res := res || '  ';
      end if;
      comma_flg := true;
      res := res || rec.attname || ' ' || rec.format || chr(10);
    end loop;

    for rec in
      select
        pg_catalog.pg_get_constraintdef(pco.oid, true) as ct_str
        , pg_catalog.pg_get_indexdef(pi.indexrelid, 0, true) as ci_str
      from pg_catalog.pg_class pc 
      inner join pg_catalog.pg_namespace pn 
        on pn.oid = pc.relnamespace 
      inner join pg_catalog.pg_index pi 
        on pc.oid = pi.indrelid 
      inner join pg_catalog.pg_class pc2 
        on pi.indexrelid = pc2.oid 
      left join pg_catalog.pg_constraint pco 
        on ( 
          pco.conrelid = pi.indrelid 
          and pco.conindid = pi.indexrelid 
          and pco.contype in ('p', 'u', 'x')
        ) 
      where
        pn.nspname = schema_name 
        and pc.relname = table_name 
      order by
        pi.indisprimary desc
        , pi.indisunique desc
        , pc.relname
    loop

      --インデックス部分作成
      if rec.ct_str is not null then

        -- CREATE TABLE内定義
        res := res || '  , ' || rec.ct_str || chr(10);
      else

        -- CREATE TABLE外定義
        idx_str := idx_str || rec.ci_str || ';' || chr(10);
      end if;
    end loop; 

    for rec in
      select
        pg_catalog.pg_get_constraintdef(pr.oid, true) as condef 
      from pg_catalog.pg_constraint pr 
      inner join pg_catalog.pg_class pc 
        on pr.conrelid = pc.oid 
      inner join pg_catalog.pg_namespace pn 
        on pn.oid = pc.relnamespace 
      where
        pn.nspname = schema_name 
        and pc.relname = table_name 
        and pr.contype = 'c'
    loop

      --チェック制約部分作成
      res := res || '  , ' || rec.condef || chr(10);
    end loop;

    for rec in
      select
        pg_catalog.pg_get_constraintdef(pr.oid, true) as condef 
      from pg_catalog.pg_constraint pr 
      inner join pg_catalog.pg_class pc 
        on pr.conrelid = pc.oid 
      inner join pg_catalog.pg_namespace pn 
        on pn.oid = pc.relnamespace 
      where
        pn.nspname = schema_name 
        and pc.relname = table_name 
        and pr.contype = 'f'
    loop

      --外部キー制約部分作成
      res := res || '  , ' || rec.condef || chr(10);
    end loop;

    -- インデックス部分追加
    res := res || ');' || chr(10) || idx_str || chr(10);

    -- コメント部分作成
    with check_data(schema_name, table_name) as ( 
      select
        schema_name as schema_name
        , table_name as table_name
    ) 
    , table_data(schema_name, table_name, table_comment, positon) as ( 
      select
        pn.nspname as schema_name
        , pc.relname as table_name
        , pg_catalog.obj_description(pc.oid) as table_comment
        , 0 as positon 
      from
        pg_catalog.pg_class pc 
        inner join pg_catalog.pg_namespace pn 
          on pn.oid = pc.relnamespace 
        inner join check_data cd 
          on pn.nspname = cd.schema_name 
          and pc.relname = cd.table_name 
      where
        pg_catalog.obj_description(pc.oid) is not null
    ) 
    , column_data( 
      schema_name
      , table_name
      , column_name
      , column_comment
      , positon
    ) as ( 
      select
        cd.schema_name
        , cd.table_name
        , pa.attname as column_name
        , pg_catalog.col_description(pc.oid, pa.attnum) as column_comment
        , pa.attnum as positon 
      from
        pg_catalog.pg_attribute pa 
        inner join pg_catalog.pg_class pc 
          on pc.oid = pa.attrelid 
        inner join pg_catalog.pg_namespace pn 
          on pn.oid = pc.relnamespace 
        inner join check_data cd 
          on pn.nspname = cd.schema_name 
          and pc.relname = cd.table_name 
      where
        pa.attnum > 0 
        and pg_catalog.col_description(pc.oid, pa.attnum) is not null 
      order by
        pa.attnum
    ) 
    select
      array_to_string( 
        array ( 
          select
            str 
          from
            ( 
              select
                'COMMENT ON TABLE ' || td.table_name || ' IS ''' || td.table_comment || ''';' as str
                , td.positon 
              from
                table_data td 
              union 
              select
                'COMMENT ON COLUMN ' || cd.table_name || '.' || cd.column_name || ' IS ''' || cd.column_comment || ''';'
                 as str
                , cd.positon 
              from
                column_data cd
            ) base 
          order by
            positon
        ) 
        , chr(10)
      ) into com_str; 
    res := res || com_str;
  end if;
  return res;
end;
$$  language plpgsql;
