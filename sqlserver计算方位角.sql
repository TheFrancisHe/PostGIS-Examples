create function compute_angle(@a_lon float,@a_lat float,@b_lon float,@b_lat float)
returns float
as
begin
	--计算方位角
	declare @angle float
	set @angle=0.0
	declare @dx float
	set @dx=@b_lon-@a_lon
	declare @dy float
	set @dy=@b_lat-@a_lat
	if(@b_lon=@a_lon)
	begin
		set @angle=pi()/2.0
		if(@b_lat=@a_lat)
		begin
			set @angle=0.0
		end
		else
		begin
			set @angle=3.0*pi()/2.0
		end
	end
	else if(@b_lon>@a_lon and @b_lat>@a_lat)
	begin 
		set @angle=atan(@dx/@dy)
	end
	else if(@b_lon>@a_lon and @b_lat<@a_lat)
	begin 
		set @angle=pi()/2+atan(-@dy/@dx)
	end
	else if(@b_lon<@a_lon and @b_lat<@a_lat)
	begin 
		set @angle=pi()+atan(@dx/@dy)
	end
	else if(@b_lon<@a_lon and @b_lat>@a_lat)
	begin 
		set @angle=3.0*pi()/2.0+atan(@dy/-@dx)
	end
	set @angle=@angle*180/pi()
	return @angle
end