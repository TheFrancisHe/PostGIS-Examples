
create function create_ellipse(@a_lon decimal(16,12),@a_lat decimal(16,12),@b_lon decimal(16,12),@b_lat decimal(16,12))
returns varchar(8000)
as
begin
	--长半轴
	declare @width decimal(16,12)
	set @width=sqrt(power((@b_lon-@a_lon),2)+power((@b_lat-@a_lat),2))/2.0
	--短半轴
	declare @height decimal(16,12)
	set @height=0.58*@width
	--计算方位角
	declare @angle decimal(16,12)
	set @angle=0.0
	declare @dx decimal(16,12)
	set @dx=@b_lon-@a_lon
	declare @dy decimal(16,12)
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
	set @angle=pi()/2-@angle
	--计算椭圆中心点
	declare @diff_x decimal(16,12)
	set @diff_x=(@a_lon+@b_lon)/2.0
	declare @diff_y decimal(16,12)
	set @diff_y=(@a_lat+@b_lat)/2.0
	--wkt
	declare @wkt varchar(8000)
	set @wkt='POLYGON (('
	--间隔
	declare @interval decimal(16,12)
	set @interval=@width/50.0
	--循环构造椭圆（共计200个点）
	declare @i int
	declare @first_x decimal(16,12)
	declare @first_y decimal(16,12)
	set @i=0
	while @i<201
	begin
		declare @x decimal(16,12)
		declare @y decimal(16,12)
		if(@i<50)--第一象限
		begin
			set @x=@interval*@i
			set @y=abs(sqrt(round((1.0-power(@x,2)/power(@width,2))*power(@height,2),8)))
		end
		else if(@i>=50 and @i<100)--第四象限
		begin
			set @x=@interval*(100-@i)
			set @y=-1*abs(sqrt(round((1.0-power(@x,2)/power(@width,2))*power(@height,2),8)))
		end
		else if(@i>=100 and @i<150)--第三象限
		begin
			set @x=-1*@interval*(@i-100)
			set @y=-1*abs(sqrt(round((1.0-power(@x,2)/power(@width,2))*power(@height,2),8)))
		end
		else--第二象限
		begin
			set @x=-1*@interval*(200-@i)
			set @y=abs(sqrt(round((1.0-power(@x,2)/power(@width,2))*power(@height,2),8)))
		end
		declare @x1 decimal(16,12)
		declare @y1 decimal(16,12)
		--旋转矩阵
		set @x1=@x*cos(@angle)-@y*sin(@angle)
		set @y1=@x*sin(@angle)+@y*cos(@angle)
		declare @x2 decimal(16,12)
		declare @y2 decimal(16,12)
		--平移矩阵
		set @x2=@x1+@diff_x
		set @y2=@y1+@diff_y
		if(@i=0)
		begin
			set @first_x=@x2
			set @first_y=@y2
		end
		--构造wkt
		if(@i=200)
		begin
			set @wkt=@wkt+cast(@x2 as varchar)+' '+cast(@y2 as varchar)
		end
		else
		begin
			set @wkt=@wkt+cast(@x2 as varchar)+' '+cast(@y2 as varchar)+','
		end
		set @i=@i+1
	end 
	set @wkt=@wkt+'))'
	return @wkt
end






