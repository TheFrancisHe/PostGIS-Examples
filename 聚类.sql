select phone,cgi,bts_name,day_list,lon,lat,
ST_ClusterDBSCAN(ST_GeomFromText('POINT('||lon||' '||lat||')',4326), eps := {0}/111.0, minpoints := {1}) over () AS cid 
from stay_station  where lon is not null and lat is not null and phone='{2}';