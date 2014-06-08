/*******************************************************************

Copyright (C) Trent Schafer 2013-2014  

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program; if not, write to the Free Software Foundation, Inc.,
51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

*******************************************************************/

create or replace 
package body gapi_core
as 

    g_wallet_path varchar2(400) := '';
    g_wallet_password varchar2(400) := '';

    function authorized_request(
      p_access_token in varchar2
    , p_url in varchar2
    , p_method in varchar2 default 'GET'
    , p_content_type in varchar2 default 'application/json'
    , p_payload in varchar2 default NULL
    , p_wallet_path in varchar2 default NULL
    , p_wallet_password in varchar2 default ''
    )
    return CLOB
    AS
        l_return CLOB;
        l_response_tmp varchar2(1024);
    BEGIN
  
        set_header(1, 'Content-Type', p_content_type);
        set_header(2, 'Authorization', 'Bearer ' || p_access_token);
    
        if p_payload is not null
        then
            set_header(3, 'Content-Length', length(p_payload));
        else
            set_header(3, 'Content-Length', 0);
        end if;  
    
        l_return :=
          apex_web_service.make_rest_request(
            p_url           => p_url
          , p_http_method   => p_method
          , p_body          => p_payload
          , p_wallet_path   => g_wallet_path
          , p_wallet_pwd    => g_wallet_password
        );

        return l_return;
    
    END authorized_request;
  
  
    function authorized_request(
        p_access_token in varchar2
      , p_url in varchar2
      , p_method in varchar2 default 'POST'
      , p_content_type in varchar2 
      , p_payload in BLOB
      , p_wallet_path in varchar2 default NULL
      , p_wallet_password in varchar2 default ''
      )
      return CLOB
    AS
        l_return CLOB;
    BEGIN
        set_header(1, 'Content-Type', p_content_type);
        set_header(2, 'Authorization', 'Bearer ' || p_access_token);
        
        if p_payload is not null
        then
            set_header(3, 'Content-Length', length(p_payload));
        end if;  
    
        l_return :=
            apex_web_service.make_rest_request(
                p_url           => p_url
              , p_http_method   => p_method
              , p_body_blob     => p_payload
              , p_wallet_path   => g_wallet_path
              , p_wallet_pwd    => g_wallet_password
            );  
   
        return l_return;
    END authorized_request;  
  
  
    function get_wallet_path return varchar2
    AS
    BEGIN
    
        return g_wallet_path;
    
    END get_wallet_path;
    
    procedure set_wallet_path(
        p_path in varchar2)
    AS
    BEGIN
    
        g_wallet_path := p_path;
        
    END set_Wallet_path;
    
    function get_wallet_password return varchar2
    AS
    BEGIN
    
        return g_wallet_password;
    
    END get_wallet_password;
    
    procedure set_wallet_password(
        p_password in varchar2)
    AS
    BEGIN
    
        g_wallet_password := p_password;
        
    END set_Wallet_password;    
    
    /*
        Date returned according to the format defined in RFC3399: https://tools.ietf.org/html/rfc3339
        
        Summary:
        
        - Years in 4 digits (3)
        - Complexities of Daylight savings means it's best to use coordinated UTC (4.1)
        - Day of the week should be excluded (5.4)
        - Format should follow the convention:
          full-year: 4 digits; month: 2 sigits; day: 2 digits
          hour: 2 digits (00-23); minut: 2 digits (00-59); second: 2 digits (00-58, 00-59, 00-60 based on leap second rules)
          
          time numoffset: ("+" / "-") time hour ":" time minute
          time offset: "Z" / time-numoffset
          
          date-time: full-date "T" full-time
          
          E.g.
          
          1985-04-12T23:20:50.52Z == 12th April 1985, 11:20.50PM
          1996-12-19T16:39:57-08:00 == 19th December 1996, 4:39.57PM with an offset of -8:00. 
            (Equivelant to: 20th December 1996, 12:39.56AM in UTC)
            
        Using the function sys_extract_utc, we can get the UTC time in one go. An alternative would be:
        to_char(sysdate, 'yyyy-mm-dd') || 'T' || to_char(sysdate, 'hh24:mi:ss')||tz_offset(sessiontimezone)
          
    */
    function get_timestamp(p_time TIMESTAMP default systimestamp) return varchar2
    AS
        l_utc_timestamp TIMESTAMP;
        l_date_cmp varchar2(10);
        l_time_cmp varchar2(8);
    BEGIN
    
        l_utc_timestamp := sys_extract_utc(p_time);
        l_date_cmp := to_char(l_utc_timestamp, 'YYYY-MM-DD');
        l_time_cmp := to_char(l_utc_timestamp, 'HH24:MI:SS');
        
        
    
        RETURN l_Date_cmp || 'T' || l_time_cmp || 'Z';    
    END get_timestamp;
    
    /*
    
        The times are returned according to RFC3399: https://tools.ietf.org/html/rfc3339
        
        Use this function to return the timestamp string, back into a timestamp object with 
        the timezone of the database attached.
        
        Resources: 
        
        http://blog.watashii.com/2009/11/oracle-timezone-conversions-gmt-to-localtime/
        http://orastory.wordpress.com/2007/05/15/dates-timestamps-and-iso-8601/
        http://docs.oracle.com/cd/B19306_01/server.102/b14200/sql_elements004.htm
        http://www.techonthenet.com/oracle/functions/from_tz.php
    
    */
    
    function get_local_timestamp(
        p_timestamp in varchar2
      , p_source_time_zone in varchar2 default '+00:00'
      , p_dest_time_zone in varchar2 default sessiontimezone) return timestamp with time zone
    AS
        l_return_timestamp timestamp with time zone;
    BEGIN
    
        l_return_timestamp := to_timestamp(p_timestamp, 'yyyy-mm-dd"T"hh24:mi:ss.ff3"Z"');
        l_return_timestamp := from_tz(l_return_timestamp, p_source_time_zone);
        l_return_timestamp := l_return_timestamp at time zone p_dest_time_zone;
        
        return l_return_timestamp;
        
    
    END get_local_timestamp;    
  
end gapi_core;
/
