# pg_scripts
ポスグレ関係で作ったもの

## お品書き
* pg_get_tabledef.sql

## pg_get_tabledef
```
test=# create table code_mst(
test-#   id integer not null
test-#   , name character varying (10)
test-#   , primary key (id)
test-# );
CREATE TABLE
test=# create index test_idxon code_mst using btree(name);
CREATE INDEX
test=# comment on table code_mst is 'コードマスタ';
COMMENT
test=# comment on column code_mst.id is 'コードID';
COMMENT
test=# comment on column code_mst.name is '名称';
COMMENT
test=# create table data (
test-#   id integer not null
test-#   , unique_data integer unique
test-#   , check_data integer check (check_data > 0)
test-#   , ref_id integer references code_mst(id)
test-#   , primary key (id)
test-# );
CREATE TABLE
test=# \d code_mst
                     Table "public.code_mst"
 Column |         Type          | Collation | Nullable | Default
--------+-----------------------+-----------+----------+---------
 id     | integer               |           | not null |
 name   | character varying(10) |           |          |
Indexes:
    "code_mst_pkey" PRIMARY KEY, btree (id)
    "code_mst_idx" btree (name)

test=# \d data
                  Table "public.data"
   Column    |  Type   | Collation | Nullable | Default
-------------+---------+-----------+----------+---------
 id          | integer |           | not null |
 unique_data | integer |           |          |
 check_data  | integer |           |          |
 ref_id      | integer |           |          |
Indexes:
    "data_pkey" PRIMARY KEY, btree (id)
    "data_unique_data_key" UNIQUE CONSTRAINT, btree (unique_data)
Check constraints:
    "data_check_data_check" CHECK (check_data > 0)
Foreign-key constraints:
    "data_ref_id_fkey" FOREIGN KEY (ref_id) REFERENCES code_mst(id)

test=# select pg_get_tabledef('public', 'code_mst');
                      pg_get_tabledef
-----------------------------------------------------------
 DROP TABLE IF EXISTS code_mst CASCADE;                   +
 CREATE TABLE code_mst(                                   +
   id integer not null                                    +
   , name character varying(10)                           +
   , PRIMARY KEY (id)                                     +
 );                                                       +
 CREATE INDEX code_mst_idx ON code_mst USING btree (name);+
                                                          +
 COMMENT ON TABLE code_mst IS 'コードマスタ';             +
 COMMENT ON COLUMN code_mst.id IS 'コードID';             +
 COMMENT ON COLUMN code_mst.name IS '名称';
(1 row)

test=# select pg_get_tabledef(null, 'data');
                 pg_get_tabledef
--------------------------------------------------
 DROP TABLE IF EXISTS data CASCADE;              +
 CREATE TABLE data(                              +
   id integer not null                           +
   , unique_data integer                         +
   , check_data integer                          +
   , ref_id integer                              +
   , PRIMARY KEY (id)                            +
   , UNIQUE (unique_data)                        +
   , CHECK (check_data > 0)                      +
   , FOREIGN KEY (ref_id) REFERENCES code_mst(id)+
 );                                              +
                                                 +

(1 row)

test=#
```

