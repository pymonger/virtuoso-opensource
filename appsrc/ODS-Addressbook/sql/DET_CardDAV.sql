--
--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--
use DB
;

create function "CardDAV_FIXNAME" (in mailname any) returns varchar
{
  return
    replace (
    replace (
    replace (
    replace (
    replace (
    replace (
    replace (
    replace (
    replace (mailname, '/', '_'), '\\', '_'), ':', '_'), '+', '_'), '\"', '_'), '[', '_'), ']', '_'), '''', '_'), ' ', '_');
}
;

create function "CardDAV_COMPOSE_ICS_NAME" (in uid varchar) returns varchar
{
  return replace(sprintf('%s.vcf', uid), '@', '-');
}
;

create function "CardDAV_ACCESS_PARAMS" (
  in detcol_id any,
  out access varchar,
  out gid integer,
  out uid integer)
{
  whenever not found goto ret;

  access := '110000000NN';
  gid := http_nogroup_gid ();
  uid := http_nobody_uid ();
  if (isinteger (detcol_id))
    select COL_PERMS, COL_GROUP, COL_OWNER into access, gid, uid from WS.WS.SYS_DAV_COL where COL_ID = detcol_id;

  ret: ;
}
;

--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "CardDAV_DAV_AUTHENTICATE" (
  in id any,
  in what char(1),
  in req varchar,
  in auth_uname varchar,
  in auth_pwd varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('CardDAV_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, http_dav_uid(), ')');
  declare domain_id, item_id integer;
  declare rc any;

  rc := '';
  domain_id := id[3];
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    return -1;

  if ('R' = what)
  {
    item_id := id[4];
    if (not exists (select 1 from AB.WA.PERSONS where P_ID = item_id))
      return -1;

    rc := AB.WA.acl_check (domain_id, item_id);
  }
  else
  {
    rc := AB.WA.acl_check (domain_id);
  }
  if (rc <> '')
  {
    if ((rc = 'R') and (req = '1__'))
      return http_nobody_uid ();

    if ((rc = 'W') and (req = '11_'))
      return http_nobody_uid ();
  }
  return -20;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "CardDAV_DAV_AUTHENTICATE_HTTP" (
  in id any,
  in what char(1),
  in req varchar,
  in can_write_http integer,
  inout a_lines any,
  inout a_uname varchar,
  inout a_pwd varchar,
  inout a_uid integer,
  inout a_gid integer,
  inout _perms varchar) returns integer
{
  -- dbg_obj_princ ('CardDAV_DAV_AUTHENTICATE_HTTP (', id, what, req, can_write_http, a_lines, a_uname, a_pwd, a_uid, a_gid, _perms, ')');
  declare domain_id, item_id integer;
  declare rc any;

  rc := '';
  domain_id := id[3];
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    return -1;

  if ('R' = what)
  {
    item_id := id[4];
    if (not exists (select 1 from AB.WA.PERSONS where P_ID = item_id))
      return -1;

    rc := AB.WA.acl_check (domain_id, item_id);
  }
  else
  {
    rc := AB.WA.acl_check (domain_id);
  }
  if (rc <> '')
  {
    a_uid := http_nobody_uid ();
    a_gid := http_nogroup_gid ();
    if (rc = 'R')
      _perms := '1__';
    else if (rc = 'W')
      _perms := '11_';

    return a_uid;
  }
  return -20;
}
;

--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "CardDAV_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_GET_PARENT (', id, st, path, ')');
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "CardDAV_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "CardDAV_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "CardDAV_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "CardDAV_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
  --dbg_obj_princ ('CardDAV_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  declare top_id any;
  declare rc, muser_id, domain_id integer;

  top_id := "CardDAV_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, 'R', muser_id, domain_id);
  if (top_id = -1)
    return -20;

  AB.WA.contact_delete (top_id[4], domain_id);
  return 1;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "CardDAV_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  --dbg_obj_princ ('CardDAV_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ', content, type, permissions, uid, gid, auth_uid, ')');
  declare top_id, res any;
  declare muser_id, domain_id, rc integer;

  top_id := "CardDAV_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, 'R', muser_id, domain_id);
  if (top_id = -1)
  {
    ;
  }
  else
  {
    AB.WA.contact_delete (top_id[4], domain_id);
  }
  declare real_content any;
  if (__tag (content) = 126)
  {
    real_content := http_body_read (1);
    real_content := string_output_string (real_content);  -- check if bellow code can work with string session and if so remove this line
    content := real_content;
  }
  res := AB.WA.import_vcard (domain_id, content);
  if (length(res) > 0)
    return vector (UNAME'CardDAV', detcol_id, uid, domain_id, path_parts[1], 0);

  return -20;
}
;

--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "CardDAV_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
  -- dbg_obj_princ ('CardDAV_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "CardDAV_DAV_PROP_SET" (
  in id any,
  in what char(0),
  in propname varchar,
  in propvalue any,
  in overwrite integer,
  in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname = 'virt:aci_meta')
  {
    declare domain_id, item_id integer;

    domain_id := id[3];
    if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
      return -1;

    if ('R' = what)
    {
      item_id := id[4];
      if (not exists (select 1 from AB.WA.PERSONS where P_ID = item_id))
        return -1;

      AB.WA.contact_update2 (item_id, domain_id, 'P_ACL', serialize (propvalue));
      return 1;
    }
    else
    {
      update DB.DBA.WA_INSTANCE
         set WAI_ACL = serialize (propvalue)
       where WAI_ID = domain_id;
      return 1;
    }
    return -16;
  }
  if (propname[0] = 58)
    return -16;

  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "CardDAV_DAV_PROP_GET" (
  in id any,
  in what char(0),
  in propname varchar,
  in auth_uid integer)
{
  -- dbg_obj_princ ('CardDAV_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  if ('virt:aci_meta' = propname)
  {
    declare domain_id, item_id integer;

    domain_id := id[3];
    if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
      return -1;

    if ('R' = what)
    {
      item_id := id[4];
      if (not exists (select 1 from AB.WA.PERSONS where P_ID = item_id))
        return -1;

      return (select deserialize (P_ACL) from AB.WA.PERSONS where P_DOMAIN_ID = domain_id and P_ID = item_id);
    }
    else
    {
      return (select deserialize (WAI_ACL) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
    }
  }
  if (':virtdet' = propname)
  {
    if ('R' = what)
      return null;

    return '';
  }
  return -11;
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "CardDAV_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('CardDAV_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "CardDAV_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  declare domain_id integer;
  declare colname, fullpath, rightcol varchar;
  declare maxrcvdate datetime;
  declare owner_gid, owner_uid integer;
  declare access varchar;

  "CardDAV_ACCESS_PARAMS" (id[1], access, owner_gid, owner_uid);

  domain_id := id[3];
  if (maxrcvdate is null)
    maxrcvdate := coalesce ( (select max(P_UPDATED) from AB.WA.PERSONS where P_DOMAIN_ID = domain_id), cast ('1980-01-01' as datetime));

  if (cast (maxrcvdate as integer) = 0)
    maxrcvdate := cast ('1980-01-01' as datetime);

  colname := (select "CardDAV_FIXNAME" (C.WAI_NAME)
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = id[2]
                 and B.WAM_USER = A.U_ID
                 and B.WAM_MEMBER_TYPE = 1
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_TYPE_NAME = 'AddressBook'
                 and C.WAI_ID = domain_id);
  if (DAV_HIDE_ERROR (colname) is null)
    return -1;

  if (path is not null)
  {
    rightcol := path[length(path) - 2];
    if ('C' = what)
      return vector (DAV_CONCAT_PATH ('/', path), 'C', 0, maxrcvdate, id, access, 0, id[2], maxrcvdate, 'dav/unix-directory', rightcol );
  }
  fullpath := DAV_CONCAT_PATH (DAV_SEARCH_PATH (id[1], 'C'), colname || '/');
  if ('C' = what)
  {
    if (id[4] > 0)
      return -1;

    return vector (fullpath, 'C', 0, maxrcvdate, id, access, 0, id[2], maxrcvdate, 'dav/unix-directory', colname );
  }
  for (select "CardDAV_COMPOSE_ICS_NAME"(P_UID) as orig_mname, P_UPDATED from AB.WA.PERSONS where P_ID = id[4]) do
    return vector (fullpath || orig_mname, 'R', 1024, P_UPDATED, id, access, 0, id[2], P_UPDATED, 'text/vcard', orig_mname);

  return -1;
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "CardDAV_DAV_DIR_LIST" (
  in detcol_id any,
  in path_parts any,
  in detcol_path varchar,
  in name_mask varchar,
  in recursive integer,
  in auth_uid integer) returns any
{
  --dbg_obj_princ ('CardDAV_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid,  ')');
  declare domain_id, owner_gid, owner_uid integer;
  declare top_davpath, access varchar;
  declare res any;
  declare top_id, descnames any;
  declare what char (1);

  "CardDAV_ACCESS_PARAMS" (detcol_id, access, owner_gid, owner_uid);
  what := case when ((0 = length (path_parts)) or ('' = path_parts[length (path_parts) - 1])) then 'C' else 'R' end;
  if (isarray (detcol_id) and (recursive = -1))
    return "CardDAV_DAV_DIR_SINGLE" (detcol_id, what, CardDAV_DAV_SEARCH_PATH (detcol_id, what), auth_uid);

  domain_id := 0;
  if ('C' = what and 1 = length(path_parts))
  {
    top_id := vector (UNAME'CardDAV', detcol_id, owner_uid, 0, 0, 0); -- may be a fake id because top_id[3] may be NULL
  } else {
    top_id := "CardDAV_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, owner_uid, domain_id);
  }
  if (DAV_HIDE_ERROR (top_id) is null)
    return vector();

  top_davpath := DAV_CONCAT_PATH (detcol_path, path_parts);
  if ('R' = what)
    return vector ("CardDAV_DAV_DIR_SINGLE" (top_id, what, top_davpath, auth_uid));

  res := vector();
  if ('C' = what)
  {
    -- Top level
    if (top_id[3] = 0)
    {
      for select "CardDAV_FIXNAME"(C.WAI_NAME) as orig_name,
                 C.WAI_ID as dom_id
            from SYS_USERS A,
                 WA_MEMBER B,
                 WA_INSTANCE C
           where A.U_ID = owner_uid
             and B.WAM_USER = A.U_ID
             and B.WAM_MEMBER_TYPE = 1
             and B.WAM_INST = C.WAI_NAME
             and C.WAI_TYPE_NAME = 'AddressBook'
      do
      {
         res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_name) || '/', 'C', 0, now(),
                  vector (UNAME'CardDAV', detcol_id, owner_uid, dom_id, 0, 0),
                  access, owner_gid, owner_uid, now(), 'dav/unix-directory', orig_name) ) );
      }
      return res;
    }
  }
  for select "CardDAV_COMPOSE_ICS_NAME"(P_UID) as orig_mname, P_ID, P_UPDATED
        from AB.WA.PERSONS
       where P_DOMAIN_ID = top_id[3]
  do
  {
    res := vector_concat (res, vector (vector (DAV_CONCAT_PATH (top_davpath, orig_mname), 'R', 1024, P_UPDATED,
    vector (UNAME'CardDAV', detcol_id, owner_uid, top_id[3], P_ID, 0),
    access, owner_gid, owner_uid, P_UPDATED, 'text/vcard', orig_mname) ) );
  }
  return res;
}
;

create procedure "CardDAV_DAV_FC_PRED_METAS" (inout pred_metas any)
{
  pred_metas := vector(
    'P_ID',                 vector ('EVENTS'        , 0, 'integer', 'P_ID'   ),
    'P_DOMAIN_ID',              vector ('EVENTS'        , 0, 'integer', 'P_DOMAIN_ID'   ),
    'RES_NAME',                 vector ('EVENTS'             , 0, 'varchar'  , '"CardDAV_COMPOSE_ICS_NAME"(_top.P_UID)'),
    'RES_FULL_PATH',            vector ('EVENTS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''addressbook''), "CardDAV_FIXNAME" (WAI_NAME), ''/'', "CardDAV_COMPOSE_ICS_NAME" (_top.P_UID)'),
    'RES_TYPE',                 vector ('EVENTS'     , 0, 'varchar'  , '(''text/vcard'')'),
    'RES_OWNER_ID',             vector ('SYS_USERS'       , 0, 'integer'  , 'U_ID'        ),
    'RES_OWNER_NAME',           vector ('SYS_USERS'       , 0, 'varchar'  , 'U_NAME'      ),
    'RES_GROUP_ID',             vector ('SYS_USERS'     , 0, 'integer'  , 'http_nogroup_gid()'  ),
    'RES_GROUP_NAME',           vector ('SYS_USERS'     , 0, 'varchar'  , '(''nogroup'')'       ),
    'RES_COL_FULL_PATH',        vector ('EVENTS'     , 0, 'varchar'  , 'concat (DAV_CONCAT_PATH (_param.detcolpath, ''addressbook''), "CardDAV_FIXNAME" (WAI_NAME), ''/'')'      ),
    'RES_COL_NAME',             vector ('EVENTS'     , 0, 'varchar'  , '"CardDAV_FIXNAME" (WAI_NAME)'   ),
    'RES_CR_TIME',              vector ('EVENTS'     , 0, 'datetime' , 'P_UPDATED'        ),
    'RES_MOD_TIME',             vector ('EVENTS'     , 0, 'datetime' , 'P_UPDATED'  ),
    'RES_PERMS',                vector ('EVENTS'     , 0, 'varchar'  , '(''110100000RR'')'   ),
    'RES_CONTENT',              vector ('EVENTS'     , 0, 'text'     , 'P_INTERESTS'   ),
    'PROP_NAME',        vector ('EVENTS'    , 0, 'varchar'  , '(''P_INTERESTS'')' ),
    'PROP_VALUE',       vector ('SYS_DAV_PROP'  , 1, 'text' , 'P_INTERESTS'   ),
    'RES_TAGS',         vector ('all-tags'  , 0, 'varchar'  , 'P_TAGS'  ), -- 'varchar', not 'text-tag' because there's no free-text on union
    'RES_PUBLIC_TAGS',      vector ('public-tags'   , 0, 'varchar'  , 'P_TAGS'  ), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RES_PRIVATE_TAGS',     vector ('private-tags'  , 0, 'varchar'  , 'P_TAGS'  ), -- 'varchar', not 'text-tag' because there's no free-text in table!
    'RDF_PROP',         vector ('fake-prop' , 1, 'varchar'  , NULL  ),
    'RDF_VALUE',        vector ('fake-prop' , 2, 'XML'  , NULL  ),
    'RDF_OBJ_VALUE',        vector ('fake-prop' , 3, 'XML'  , NULL  )
  );
}
;

create procedure "CardDAV_DAV_FC_TABLE_METAS" (inout table_metas any)
{
  table_metas := vector (
    'PERSONS'             , vector (      ''      ,
                                        ''      ,
                                                'P_NAME'    , 'P_NAME'  , '[__quiet] /' ),
    'WA_INSTANCE'         , vector (      ''      ,
                                        ''      ,
                                                'WAI_NAME'     , 'WAI_NAME'   , '[__quiet] /' ),
    'WA_MEMBER'         , vector (      ''      ,
                                        ''      ,
                                                'WAM_INST'     , 'WAM_INST'   , '[__quiet] /' ),

    'SYS_USERS'   , vector (      ''      ,
                                        ''      ,
                                                NULL            , NULL          , NULL          ),
    'public-tags'   , vector (  '  '    ,
                                    ''  ,
                        'P_TAGS'    , 'P_TAGS'  , NULL  ),
    'private-tags'  , vector (  ' ' ,
                    ' ' ,
                        'P_TAGS'    , 'P_TAGS'  , NULL  ),
    'all-tags'      , vector (  ' ' ,
                    ' ' ,
                        'P_TAGS'    , 'P_TAGS'  , NULL  ),
    'fake-prop' , vector (  '\n  inner join WS.WS.SYS_DAV_PROP as ^{alias}^ on ((^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)' ,
                    '\n  exists (select 1 from WS.WS.SYS_DAV_PROP as ^{alias}^ where (^{alias}^.PROP_PARENT_ID is null) and (^{alias}^.PROP_TYPE = ''R'')^{andpredicates}^)'    ,
                        'PROP_VALUE'    , 'PROP_VALUE'  , '[__quiet __davprop xmlns:virt="virt"] fakepropthatprobablyneverexists'   )
    );
}
;

create function "CardDAV_DAV_FC_PRINT_WHERE" (inout filter any, in param_uid integer) returns varchar
{
  declare pred_metas, cmp_metas, table_metas any;
  declare used_tables any;
  -- dbg_obj_princ ('Blog_POST_DAV_FC_PRINT_WHERE (', filter, param_uid, ')');
  "CardDAV_DAV_FC_PRED_METAS" (pred_metas);
  DAV_FC_CMP_METAS (cmp_metas);
  "CardDAV_DAV_FC_TABLE_METAS" (table_metas);
  used_tables := vector(
      'PERSONS', vector ('PERSONS', '_top', null, vector (), vector (), vector ()),
      'WA_INSTANCE', vector ('WA_INSTANCE', '_instances', null, vector (), vector (), vector ()),
      'WA_MEMBER', vector ('WA_MEMBER', '_members', null, vector (), vector (), vector ()),
      'SYS_USERS', vector ('SYS_USERS', '_users', null, vector (), vector (), vector ())
  );
  return DAV_FC_PRINT_WHERE_INT (filter, pred_metas, cmp_metas, table_metas, used_tables, param_uid);
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "CardDAV_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path any, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
    --dbg_obj_princ ('CardDAV_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
    declare st, access, qry_text, execstate, execmessage varchar;
    declare res any;
    declare cond_list, execmeta, execrows any;
    declare sub, post_id, condtext, cond_key varchar;
    declare owner_gid, owner_uid, domain_id integer;
    "CardDAV_ACCESS_PARAMS" (detcol_id, access, owner_gid, owner_uid);
    vectorbld_init (res);
    sub := null;
    post_id := null;
    if (((length (path_parts) <= 1) and (recursive <> 1)) or (length (path_parts) > 2))
    {
      -- dbg_obj_princ ('\r\nGoto skip_post_level\r\n');
      goto finalize;
    }
    if (length (path_parts) >= 2)
    {
        sub := path_parts[0];
        if (sub = 'addressbooks')
        {
            domain_id := coalesce ((select C.WAI_ID
                from SYS_USERS A,
                WA_MEMBER B,
                WA_INSTANCE C
            where A.U_ID = owner_uid
              and B.WAM_USER = A.U_ID
              and B.WAM_MEMBER_TYPE = 1
              and B.WAM_INST = C.WAI_NAME
              and C.WAI_TYPE_NAME = 'AddressBook'
              and "CardDAV_FIXNAME"(C.WAI_NAME) = path_parts[1]));
            if (domain_id is null)
                goto finalize;
        }
        else
            goto finalize;
    }
    cond_key := sprintf ('AddressBook&%d', coalesce (domain_id, 0));
    condtext := get_keyword (cond_key, compilation);
    if (condtext is null and 0)
    {
      cond_list := get_keyword ('', compilation);
      if (sub is not null)
        cond_list := vector_concat (cond_list, vector ( vector ('P_DOMAIN_ID', '=', domain_id)));
      condtext := "CardDAV_DAV_FC_PRINT_WHERE" (cond_list, auth_uid);
      compilation := vector_concat (compilation, vector (cond_key, condtext));
    }
    execstate := '00000';
        qry_text := 'select concat (DAV_CONCAT_PATH (_param.detcolpath, ''addressbook''), ''/'', "CardDAV_FIXNAME" (WAI_NAME), ''/'', "CardDAV_COMPOSE_ICS_NAME" (_top.P_UID)),
        ''R'', 1024, _top.P_UPDATED,
                vector (UNAME_ADDRESSBOOK(), ?, _users.U_ID, 3, _top.P_DOMAIN_ID, 0, 0, 0, 0),
                ''110100000RR'', http_nogroup_gid(), _users.U_ID, _top.P_UPDATED, ''text/vcard'', "CardDAV_COMPOSE_ICS_NAME" (_top.P_UID)
        from
        (select top 1 ? as detcolpath from WS.WS.SYS_DAV_COL) as _param,
        AB.WA.PERSONS as _top
        join DB.DBA.WA_INSTANCE as _instances on (WAI_ID = P_DOMAIN_ID and WAI_TYPE_NAME = ''AddressBook'')
                join DB.DBA.WA_MEMBER as _members on (WAM_MEMBER_TYPE = 1 and WAM_INST = WAI_NAME)
                join DB.DBA.SYS_USERS as _users on (WAM_USER = U_ID and U_ID = ?)
        ' || condtext;
      exec (qry_text, execstate, execmessage,
        vector (detcol_id, detcol_path, owner_uid),
        100000000, execmeta, execrows );
      if ('00000' <> execstate)
        signal (execstate, execmessage || ' in ' || qry_text);
      vectorbld_concat_acc (res, execrows);
finalize:
    vectorbld_final (res);
    return res;
}
;

create function UNAME_ADDRESSBOOK () returns any
{
  return UNAME'CardDAV';
}
;

create function "CardDAV_DAV_SEARCH_ID_IMPL" (in detcol_id any, in path_parts any, in what char(1), inout muser_id integer, inout domain_id integer) returns any
{
    --dbg_obj_princ ('CardDAV_DAV_SEARCH_ID_IMPL (', detcol_id, path_parts, what, muser_id, domain_id, ')');
    declare owner_gid, owner_uid, ctr, len integer;
    declare hitlist any;
    declare access, colpath varchar;
    "CardDAV_ACCESS_PARAMS" (detcol_id, access, owner_gid, owner_uid);
  muser_id := owner_uid;
    if (0 = length(path_parts))
    {
        if ('C' <> what)
            return -1;
        return vector (UNAME'CardDAV', detcol_id, owner_uid, domain_id, 0, 0);
    }
    if ('' = path_parts[length(path_parts) - 1])
    {
        if ('C' <> what)
            return -1;
    }
    else
    {
        if ('R' <> what)
            return -1;
    }
    len := length (path_parts) - 1;
    ctr := 0;
    while (ctr < len)
    {
        if (ctr = 0)
        {
            hitlist := vector ();
            for select C.WAI_ID as D_ID
                     from SYS_USERS A,
                          WA_MEMBER B,
                          WA_INSTANCE C
                    where A.U_ID = owner_uid
                      and B.WAM_USER = A.U_ID
                      and B.WAM_MEMBER_TYPE = 1
                      and B.WAM_INST = C.WAI_NAME
                      and C.WAI_TYPE_NAME = 'AddressBook'
                      and "CardDAV_FIXNAME"(C.WAI_NAME) = path_parts[ctr]
            do
            {
                hitlist := vector_concat (hitlist, vector (D_ID));
            }
            if (length (hitlist) <> 1)
                return -1;
            domain_id := hitlist[0];
        }
        else if (ctr = 1 and len > 1)
    {
            return -1;
    }
        ctr := ctr + 1;
    }
    if ('C' = what)
        return vector (UNAME'CardDAV', detcol_id, owner_uid, domain_id, 0, 0);
    hitlist := vector ();
  for select distinct P_ID
    from AB.WA.PERSONS
    where "CardDAV_COMPOSE_ICS_NAME" (P_UID) = path_parts[ctr] and P_DOMAIN_ID = domain_id
  do
  {
    hitlist := vector_concat (hitlist, vector (P_ID));
  }
    if (length (hitlist) <> 1)
        return -1;
    return vector (UNAME'CardDAV', detcol_id, owner_uid, domain_id, hitlist[0], 0);
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "CardDAV_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare u_id, domain_id integer;
  domain_id := 0;
  --dbg_obj_princ ('CardDAV_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  return "CardDAV_DAV_SEARCH_ID_IMPL" (detcol_id, path_parts, what, u_id, domain_id);
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "CardDAV_DAV_SEARCH_PATH" (
  in id any,
  in what char(1)) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_SEARCH_PATH (', id, what, ')');
  declare path varchar;
  declare domain_id, item_id integer;

  path := DAV_SEARCH_PATH (id[1], 'C');
  domain_id := id[3];
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    return null;

  path := path || "CardDAV_FIXNAME" (AB.WA.domain_name (domain_id)) || '/';
  if ('C' = what)
    return path;

  item_id := id[4];
  for (select P_UID from AB.WA.PERSONS where P_ID = item_id) do
    return  path || "CardDAV_COMPOSE_ICS_NAME" (P_UID);

  return null;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "CardDAV_DAV_RES_UPLOAD_COPY" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "CardDAV_DAV_RES_UPLOAD_MOVE" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite_flags integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  return -20;
}
;


--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "CardDAV_DAV_RES_CONTENT" (
  in id any,
  inout content any,
  out type varchar,
  in content_mode integer) returns integer
{
  --dbg_obj_princ ('CardDAV_DAV_RES_CONTENT (', id, ', content, type, ', content_mode, ')');
  declare tz integer;

  type := 'text/vcard';
  whenever not found goto endline;
  if (id[4] is not null)
    content := AB.WA.export_vcard (id[3], vector(id[4]));

endline:
  return 0;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "CardDAV_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "CardDAV_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "CardDAV_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "CardDAV_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_LOCK (', id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, owner_name, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "CardDAV_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('CardDAV_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "CardDAV_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
  -- dbg_obj_princ ('CardDAV_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "CardDAV_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
  -- dbg_obj_princ ('CardDAV_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;
