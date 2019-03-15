xquery version "3.1";

module namespace wdbRe = "https://github.com/dariok/wdbplus/RestEntities";

import module namespace console ="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace wdb     = "https://github.com/dariok/wdbplus/wdb" at "../modules/app.xqm";

declare namespace http   = "http://expath.org/ns/http-client";
declare namespace meta   = "https://github.com/dariok/wdbplus/wdbmeta";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace tei    = "http://www.tei-c.org/ns/1.0";

declare
    %rest:GET
    %rest:path("/edoc/entities/scan/{$type}/{$collection}/{$q}")
function wdbRe:scan ($collection as xs:string, $type as xs:string*, $q as xs:string*) {
  let $query := xmldb:decode($q)
  
  let $res := switch ($type)
    case "bibl" return collection($wdb:data)//tei:title[matches(., $query)][ancestor::tei:listBibl]
    case "person" return collection($wdb:data)//tei:persName[matches(., $query)][ancestor::tei:listPerson]
    case "place" return collection($wdb:data)//tei:placeName[matches(., $query)][ancestor::tei:listPlace]
    case "org" return collection($wdb:data)//tei:orgName[matches(., $query)][ancestor::tei:listOrg]
    default return ()
    
  return if ($res = ())
  then "Error: no or wrong type"
  else <results q="{$query}" type="{$type}" collection="{$collection}">{
    for $r in $res
    group by $id := $r/ancestor::*[@xml:id][1]/@xml:id
    return
      <result id="{$id}" />
  }</results>
};

declare
    %rest:GET
    %rest:path("/edoc/entities/collection/{$collection}/{$ref}")
    %rest:query-param("start", "{$start}", 1)
function wdbRe:collectionEntity ($collection as xs:string*, $ref as xs:string*, $start as xs:int*) {
  let $coll := wdb:getProject($collection)
  let $query := xmldb:decode($ref)
  
  let $res := collection($coll)//tei:rs[@ref=$query or @ref='#'||$query]
  let $max := count($res)
  
  return
    <results count="{$max}" from="{$start}" id="{$collection}" ref="{$ref}">{
      for $f in subsequence($res, $start, 25)
      group by $file := $f/ancestor::tei:TEI/@xml:id
      return
        <file id="{$file}" />
    }</results>
};

declare
    %rest:GET
    %rest:path("/edoc/entities/file/{$id}/{$ref}")
    %rest:query-param("start", "{$start}", 1)
function wdbRe:fileEntity ($id as xs:string*, $ref as xs:string*, $start as xs:int*) {
  let $file := (collection($wdb:data)/id($id))[self::tei:TEI][1]
  let $query := lower-case(xmldb:decode($ref))
  
  let $res := $file//tei:rs[@ref=$query or @ref = '#'||$query]
  let $max := count($res)
  
  return
    <results count="{$max}" from="{$start}" id="{$id}" ref="{$ref}">{
      for $h in subsequence($res, $start, 25)
      group by $a := ($h/ancestor-or-self::*[@xml:id])[last()]
      return
        <result fragment="{$a/@xml:id}">{
          $h
        }</result>
    }</results>
};

declare
    %rest:GET
    %rest:path("/edoc/entities/list/collection/{$id}/{$q}")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("p", "{$p}")
function wdbRe:listCollectionEntities ($id as xs:string*, $q as xs:string*, $start as xs:int*, $p as xs:string*) {
  let $md := collection($wdb:data)//id($id)[self::meta:projectMD]
  
  let $coll := wdb:getEdPath(base-uri($md), true())
  let $query := xmldb:decode($q)
  
  let $params := parse-json($p)
  
  let $r := if ($p != "" and $params("type") != "")
    then collection($coll)//tei:rs[starts-with(@ref, $query) and @type = $params("type")]
    else collection($coll)//tei:rs[starts-with(@ref, $query)]
  let $res := for $f in $r
    group by $ref := $f/@ref
    return
      <result ref="{$ref}" count="{count($f)}">
        {for $id in distinct-values($f/ancestor::tei:TEI/@xml:id)
          return <file id="{$id}" />
        }
      </result>
  let $max := count($res)
  
  return
    <results count="{$max}" from="{$start}" id="{$id}" q="{$q}" p="{$p}">{
      for $f in subsequence($res, $start, 25)
      return $f
    }</results>
};

declare
    %rest:GET
    %rest:path("/edoc/entities/list/file/{$id}/{$q}")
    %rest:query-param("start", "{$start}", 1)
    %rest:query-param("p", "{$p}")
function wdbRe:listFileEntities ($id as xs:string*, $q as xs:string*, $start as xs:int*, $p as xs:string*) {
  let $file := (collection($wdb:data)/id($id))[self::tei:TEI][1]
  let $query := lower-case(xmldb:decode($q))
  
  let $params := parse-json($p)
  
  let $r := if ($p != "" and $params("type") != "")
    then $file//tei:rs[starts-with(@ref, $query) and @type = $params("type")]
    else $file//tei:rs[starts-with(@ref, $query)]
  let $res := for $f in $r
    group by $ref := $f/@ref
    return
      <result ref="{$ref}">
        {for $i in $f
          group by $id := $i/ancestor::tei:*[@xml:id][1]/@xml:id
          return <fragment id="{$id}" />
        }
      </result>
  let $max := count($res)
  
  return
    <results count="{$max}" from="{$start}" id="{$id}" q="{$q}">{
      for $h in subsequence($res, $start, 25) return
        <result ref="{$h/@ref}" count="{count($h/*)}">
          {$h/*}
        </result>
    }</results>
};