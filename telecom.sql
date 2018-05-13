/*
电信数据处理
[医疗]
[机票]
*/


-- bulk insert
BULK INSERT splitfile1 FROM 'C:\data\lte\splitfile1.txt'  
  WITH (  
      FIELDTERMINATOR = '\t',  
      ROWTERMINATOR = '\n'  
  );  


-- batch bulk insert
declare @count int
declare @spath varchar(500)
set @count=5
while @count<=330
begin
	set @spath = '''C:\data\lte\splitFile' + cast(@count as varchar(50)) + '.txt'''
	exec('BULK INSERT lte FROM ' + @spath + 'WITH (FIELDTERMINATOR = ''\t'', ROWTERMINATOR = ''\n'')')
	set @count = @count + 1
end


-- 修改表结构
ALTER TABLE lte   
ADD urldomain varchar(500) null  
GO
ALTER TABLE lte   
ADD timestamp1 datetime null
GO
alter table lte 
alter column userid varchar(100) null
GO
alter table lte 
alter column timestamp varchar(50) null
GO


-- 变换unix时间戳、提取url的域名
update [lte]
set urldomain=LEFT(url,CHARINDEX('/',url)-1),
	timestamp1=DATEADD(S,CAST( SUBSTRING(timestamp,1,10) AS INT ) + 8 * 3600,'1970-01-01 00:00:00')
where url is not null and CHARINDEX('/',url)>1


-- [医疗]统计域名访问次数
SELECT h.url url
      ,COUNT(*) cnt
INTO [data].[dbo].[sitecount]
FROM [data].[dbo].[healthsites] h
INNER JOIN [data].[dbo].[vLte] v
ON h.url = v.url1
GROUP BY h.url
ORDER BY cnt DESC
GO
SELECT h.url url
      ,h.name name
      ,h.category category
      ,ISNULL(c.cnt, 0) cnt
FROM [data].[dbo].[healthsites] h
LEFT JOIN [data].[dbo].[sitecount] c
ON h.url = c.url
ORDER BY cnt DESC
GO


-- [机票]导出ceair和ctrip的访问记录
-- ceair
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'ceair' AS [website]
      ,[channel] =
      CASE url1
          WHEN 'mobile.ceair.com' THEN 'app'
          ELSE 'browser'
      END
INTO [data].[dbo].[airflight]
FROM [data].[dbo].[vLte]
WHERE url1 IN ('mobile.ceair.com', 'm.ceair.com', 'www.ceair.com')
GO
-- ctrip
INSERT INTO [data].[dbo].[airflight]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'ctrip' AS [website]
      ,[channel] =
      CASE
          WHEN agent LIKE '%okhttp%' THEN 'app'
          WHEN agent LIKE '%Dalvik%' THEN 'app'
          WHEN agent LIKE '%Darwin%' THEN 'app'
          WHEN agent LIKE '%Ctrip%' THEN 'app'
          ELSE 'browser'
      END
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%flight%ctrip%'
    OR url1='m.ctrip.com'
    OR url1 LIKE '%ctrip.com' AND url LIKE '%flight%' AND url1 NOT LIKE '%flight%' AND url1 <> 'm.ctrip.com'
GO


-- [机票]导出其他网站的访问记录
USE data
GO

ALTER TABLE airflight
ALTER COLUMN website VARCHAR(10) NULL
GO

ALTER TABLE airflight
ALTER COLUMN channel VARCHAR(10) NULL
GO

INSERT INTO [data].[dbo].[airflight]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,[website] =
      CASE
          WHEN url1 IN ('www.ly.com', 'm.ly.com') THEN 'ly'
          WHEN url1 IN ('m.tuniu.com', 'flight-api.tuniu.com') THEN 'tuniu'
          WHEN url1 = 'm.elong.com' THEN 'elong'
          WHEN url1 IN ('www.airchina.com.cn', 'm.airchina.com', 'm.airchina.com.cn') THEN 'airchina'
          WHEN url1 IN ('airport.csair.com', 'www.csair.com', 'm.csair.com', 'b2c.csair.com', 'wxapi.csair.com') THEN 'csair'
          WHEN url1 LIKE '%juneyaoair.com' THEN 'juneyaoair'
      END
      ,NULL AS [channel]
FROM [data].[dbo].[vLte]
WHERE url LIKE '%flight%'
    AND url1 IN ('www.ly.com', 'm.ly.com', 'm.tuniu.com', 'flight-api.tuniu.com', 'm.elong.com')
    OR url1 IN ('www.airchina.com.cn', 'm.airchina.com', 'm.airchina.com.cn', 'airport.csair.com', 'www.csair.com', 'm.csair.com', 'b2c.csair.com', 'wxapi.csair.com')
    OR url1 LIKE '%juneyaoair.com'
GO


-- [机票]T1-T4
-- T1
SELECT [userid]
      ,date
      ,[website]
      ,[channel]
      ,COUNT(url) AS [request times]
FROM [data].[dbo].[airflight]
GROUP BY userid, date, website, channel
HAVING website IN ('ctrip', 'ceair')
ORDER BY userid, date, website, channel
GO

-- T2
SELECT [userid]
      ,[website]
      ,MIN(date) AS [date]
FROM [data].[dbo].[airflight]
GROUP BY userid, website, channel
HAVING channel='app' AND website IN ('ctrip', 'ceair')
ORDER BY userid, website
GO

-- T3
-- 创建临时表
IF OBJECT_ID('tempdb..##T2') IS NOT NULL
    DROP TABLE ##T2
GO
SELECT [userid]
      ,[website]
      ,MIN(timestamp) AS [timestamp]
INTO ##T2
FROM [data].[dbo].[airflight]
GROUP BY userid, website, channel
HAVING channel='app' AND website IN ('ctrip', 'ceair')
ORDER BY userid, website
GO
IF OBJECT_ID('tempdb..##tmp') IS NOT NULL
    DROP TABLE ##tmp
GO
SELECT [userid]
      ,[timestamp]
      ,[website]
      ,[timestamp1]
INTO ##tmp
FROM [data].[dbo].[airflight]
GO
-- before
IF OBJECT_ID('tempdb..##T3C1') IS NOT NULL
    DROP TABLE ##T3C1
GO
SELECT a.userid
      ,DATEPART(month, b.timestamp1) AS [month]
      ,COUNT(DISTINCT b.website) AS [before]
INTO ##T3C1
FROM ##T2 a
LEFT JOIN ##tmp b
ON a.userid = b.userid
WHERE a.timestamp >= b.timestamp AND a.website='ctrip'
GROUP BY a.userid, DATEPART(month, b.timestamp1)
ORDER BY a.userid, DATEPART(month, b.timestamp1)
GO
SELECT userid
      ,AVG(before) AS [before_avg]
INTO ##T3C1A
FROM ##T3C1
GROUP BY userid
ORDER BY userid
GO

-- after
IF OBJECT_ID('tempdb..##T3C2') IS NOT NULL
    DROP TABLE ##T3C2
GO
SELECT a.userid
      ,DATEPART(month, b.timestamp1) AS [month]
      ,COUNT(DISTINCT b.website) AS [after]
INTO ##T3C2
FROM ##T2 a
LEFT JOIN ##tmp b
ON a.userid = b.userid
WHERE a.timestamp < b.timestamp AND a.website='ctrip'
GROUP BY a.userid, DATEPART(month, b.timestamp1)
ORDER BY a.userid, DATEPART(month, b.timestamp1)
GO
SELECT userid
      ,AVG(after) AS [after_avg]
INTO ##T3C2A
FROM ##T3C2
GROUP BY userid
ORDER BY userid
GO

-- merge
SELECT ISNULL(a.userid, b.userid) AS userid
      ,a.before_avg
      ,b.after_avg
INTO ##T3
FROM ##T3C1A a
FULL OUTER JOIN ##T3C2A b
ON a.userid = b.userid
ORDER BY userid
GO

SELECT COUNT(userid)
FROM ##T3
WHERE before_avg < after_avg
GO

-- T4
-- before
IF OBJECT_ID('tempdb..##T4C1') IS NOT NULL
    DROP TABLE ##T4C1
GO
SELECT a.userid
      ,DATEPART(month, b.timestamp1) AS [month]
      ,COUNT(DISTINCT b.website) AS [before]
INTO ##T4C1
FROM ##T2 a
LEFT JOIN ##tmp b
ON a.userid = b.userid
WHERE a.timestamp >= b.timestamp AND a.website='ceair'
GROUP BY a.userid, DATEPART(month, b.timestamp1)
ORDER BY a.userid, DATEPART(month, b.timestamp1)
GO
SELECT userid
      ,AVG(before) AS [before_avg]
INTO ##T4C1A
FROM ##T4C1
GROUP BY userid
ORDER BY userid
GO

-- after
IF OBJECT_ID('tempdb..##T4C2') IS NOT NULL
    DROP TABLE ##T4C2
GO
SELECT a.userid
      ,DATEPART(month, b.timestamp1) AS [month]
      ,COUNT(DISTINCT b.website) AS [after]
INTO ##T4C2
FROM ##T2 a
LEFT JOIN ##tmp b
ON a.userid = b.userid
WHERE a.timestamp < b.timestamp AND a.website='ceair'
GROUP BY a.userid, DATEPART(month, b.timestamp1)
ORDER BY a.userid, DATEPART(month, b.timestamp1)
GO
SELECT userid
      ,AVG(after) AS [after_avg]
INTO ##T4C2A
FROM ##T4C2
GROUP BY userid
ORDER BY userid
GO

-- merge
SELECT ISNULL(a.userid, b.userid) AS userid
      ,a.before_avg
      ,b.after_avg
INTO ##T4
FROM ##T4C1A a
FULL OUTER JOIN ##T4C2A b
ON a.userid = b.userid
ORDER BY userid
GO


-- [医疗]导出健康相关记录
-- haodf
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'haodf' AS [website]
INTO [data].[dbo].[health_records]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.haodf.%'
GO

USE data
GO

ALTER TABLE health_records
ALTER COLUMN website VARCHAR(10) NULL
GO

-- cndzys
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'cndzys' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.cndzys.%'
GO

-- boohee
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'boohee' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.boohee.%'
GO

-- guahao
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'guahao' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.guahao.%'
GO

-- 39net
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'39net' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.39.net'
GO

-- 120ask
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'120ask' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.120.net' OR url1 LIKE '%.120ask%'
GO

-- xywy
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'xywy' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.xywy.%'
GO

-- 360kad
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'360kad' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.360kad.%'
GO

-- chunyuyisheng
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'chunyu' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.chunyuyisheng.%'
GO

-- jianke
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'jianke' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.jianke.%'
GO

-- soyoung
INSERT INTO [data].[dbo].[health_records]
SELECT [userid]
      ,[timestamp]
      ,[url]
      ,[agent]
      ,[ref]
      ,[date]
      ,[slashindex]
      ,[url1]
      ,[timestamp1]
      ,'soyoung' AS [website]
FROM [data].[dbo].[vLte]
WHERE url1 LIKE '%.soyoung.%'
GO


-- [医疗]Seasoning Trends
SELECT DATEPART(quarter,r.timestamp1) AS [quarter]
      ,s.category AS category
      ,COUNT(r.url) AS [Number of visits]
      ,COUNT(DISTINCT r.userid) AS [Unique Visitors]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] s
ON r.website = s.abbreviation
GROUP BY DATEPART(quarter,r.timestamp1), s.category
ORDER BY quarter, category
GO


-- [医疗]Week Trends
SET DATEFIRST 1;
SELECT DATEPART(weekday,r.timestamp1) AS [weekday]
      ,s.category AS category
      ,COUNT(r.url) AS [Number of visits]
      ,COUNT(DISTINCT r.userid) AS [Unique Visitors]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] s
ON r.website = s.abbreviation
GROUP BY DATEPART(weekday,r.timestamp1), s.category
ORDER BY weekday, category
GO


-- [医疗]Time Trends
SELECT DATEPART(hour,r.timestamp1) AS [hour]
      ,s.category AS category
      ,COUNT(r.url) AS [Number of visits]
      ,COUNT(DISTINCT r.userid) AS [Unique Visitors]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] s
ON r.website = s.abbreviation
GROUP BY DATEPART(hour,r.timestamp1), s.category
ORDER BY hour, category
GO


-- [机票]Intensity of use
SELECT [userid]
      ,date
      ,[website]
      ,[channel]
      ,COUNT(url) AS [request_times]
INTO ##t1
FROM [data].[dbo].[airflight]
GROUP BY userid, date, website, channel
HAVING website IN ('ctrip', 'ceair')
ORDER BY userid, date, website, channel
GO

SELECT [userid]
      ,[website]
      ,MIN(date) AS [date]
INTO ##t2
FROM [data].[dbo].[airflight]
GROUP BY userid, website, channel
HAVING channel='app' AND website IN ('ctrip', 'ceair')
ORDER BY userid, website
GO

-- ctrip_before
SELECT a.userid
      ,a.date
      ,a.website
      ,a.channel
      ,a.request_times
      ,b.date AS ctrip_initial
INTO #ctrip_before
FROM ##t1 a
RIGHT JOIN ##t2 b
ON a.userid = b.userid
WHERE b.website='ctrip' and a.date < b.date
ORDER BY a.userid, a.date, a.website, a.channel
GO
SELECT userid
      ,channel
      ,AVG(request_times) AS Intensity
FROM #ctrip_before
GROUP BY userid, channel
ORDER BY userid, channel
GO

-- ctrip_after
SELECT a.userid
      ,a.date
      ,a.website
      ,a.channel
      ,a.request_times
      ,b.date AS ctrip_initial
INTO #ctrip_after
FROM ##t1 a
RIGHT JOIN ##t2 b
ON a.userid = b.userid
WHERE b.website='ctrip' and a.date >= b.date
ORDER BY a.userid, a.date, a.website, a.channel
GO
SELECT userid
      ,channel
      ,AVG(request_times) AS Intensity
FROM #ctrip_after
GROUP BY userid, channel
ORDER BY userid, channel
GO

-- ceair_before
SELECT a.userid
      ,a.date
      ,a.website
      ,a.channel
      ,a.request_times
      ,b.date AS ceair_initial
INTO #ceair_before
FROM ##t1 a
RIGHT JOIN ##t2 b
ON a.userid = b.userid
WHERE b.website='ceair' and a.date < b.date
ORDER BY a.userid, a.date, a.website, a.channel
GO
SELECT userid
      ,channel
      ,AVG(request_times) AS Intensity
FROM #ceair_before
GROUP BY userid, channel
ORDER BY userid, channel
GO

-- ceair_after
SELECT a.userid
      ,a.date
      ,a.website
      ,a.channel
      ,a.request_times
      ,b.date AS ctrip_initial
INTO #ceair_after
FROM ##t1 a
RIGHT JOIN ##t2 b
ON a.userid = b.userid
WHERE b.website='ceair' and a.date >= b.date
ORDER BY a.userid, a.date, a.website, a.channel
GO
SELECT userid
      ,channel
      ,AVG(request_times) AS Intensity
FROM #ceair_after
GROUP BY userid, channel
ORDER BY userid, channel
GO


-- [医疗]Number of visits & Unique visitors
SELECT website
      ,COUNT(url) AS nv
      ,COUNT(DISTINCT userid) AS uv
FROM [data].[dbo].[health_records]
GROUP BY website
ORDER BY nv DESC
GO


-- [医疗]Search penetration: unique visitors
SELECT s.category
      ,COUNT(DISTINCT userid) AS uv
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] s
ON r.website = s.abbreviation
GROUP BY s.category
ORDER BY s.category DESC
GO

-- [医疗]Distribution of search effort
SELECT s.category
      ,COUNT(r.url) AS nv
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] s
ON r.website = s.abbreviation
GROUP BY s.category
ORDER BY s.category DESC
GO


-- [医疗]Diversity
IF OBJECT_ID('tempdb..#Diversity') IS NOT NULL
    DROP TABLE #Diversity
GO
IF OBJECT_ID('tempdb..#csavg') IS NOT NULL
    DROP TABLE #csavg
GO
SELECT userid
      ,DATEPART(quarter, timestamp1) AS [quarter]
      ,COUNT(DISTINCT website) AS cs
INTO #Diversity
FROM [data].[dbo].[health_records]
GROUP BY userid, DATEPART(quarter, timestamp1)
ORDER BY userid, DATEPART(quarter, timestamp1)
GO
SELECT userid
      ,AVG(cs) AS cs_avg
INTO #csavg
FROM #Diversity
GROUP BY userid
ORDER BY userid
GO
SELECT cs_avg AS cs
      ,COUNT(DISTINCT userid) AS cnt
      ,CONVERT(DECIMAL(4,4), COUNT(DISTINCT userid)/CONVERT(DECIMAL(5,2), (SELECT COUNT(DISTINCT userid) FROM #csavg))) AS pct
FROM #csavg
GROUP BY cs_avg
ORDER BY cs
GO


-- [医疗]Consideration Set each Session
IF OBJECT_ID('tempdb..#Diversity') IS NOT NULL
    DROP TABLE #Diversity
GO
SELECT userid
      ,date
      ,COUNT(DISTINCT website) AS cs
INTO #Diversity
FROM [data].[dbo].[health_records]
GROUP BY userid, date
ORDER BY userid, date
GO
SELECT cs
      ,COUNT(cs) AS sessions
      ,CONVERT(DECIMAL(4,4), COUNT(cs)/CONVERT(DECIMAL(6,2), (SELECT COUNT(cs) FROM #Diversity))) AS pct
FROM #Diversity
GROUP BY cs
ORDER BY cs
GO


-- [医疗]Number of Visits each Session
IF OBJECT_ID('tempdb..#Intensity') IS NOT NULL
    DROP TABLE #Intensity
GO
SELECT userid
      ,date
      ,COUNT(url) AS Intensity
INTO #Intensity
FROM [data].[dbo].[health_records]
GROUP BY userid, date
ORDER BY userid, date
GO
SELECT Intensity
      ,COUNT(Intensity) AS sessions
FROM #Intensity
GROUP BY Intensity
ORDER BY Intensity
GO


-- [医疗]Loyalty
SELECT r.userid
      ,h.category
      ,r.website
      ,COUNT(r.url) AS [Visit Numbers]
      ,COUNT(DISTINCT r.date) AS [Visit Days]
      ,DATEDIFF(day ,MAX(r.date), '2017-08-31') AS [Last Visit]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] h
ON r.website = h.abbreviation
GROUP BY r.userid, h.category, r.website
ORDER BY r.userid, h.category, r.website
GO


-- [医疗]Cross-browsing
IF OBJECT_ID('tempdb..##c1') IS NOT NULL
    DROP TABLE ##c1
GO
SELECT r.userid
      ,h.category
      ,COUNT(r.url) AS [Number of Visits]
INTO ##c1
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[healthsites] h
ON r.website = h.abbreviation
GROUP BY r.userid, h.category
ORDER BY r.userid, h.category
GO
SELECT category
      ,COUNT(DISTINCT userid) AS [Unique Users]
      ,SUM([Number of Visits]) AS [Number of Visits]
FROM ##c1
GROUP BY category
ORDER BY category
GO

CREATE TABLE data.dbo.CrossBrowsing  
(  
    userid varchar(100) PRIMARY KEY
    ,medical int  NULL  
    ,lifestyle int NULL  
    ,epharmacy int NULL  
);

INSERT INTO data.dbo.CrossBrowsing (userid)
SELECT DISTINCT userid
FROM ##c1
GO
USE data
GO
UPDATE CrossBrowsing set CrossBrowsing.medical = ##c1.[Number of Visits]
FROM ##c1
WHERE CrossBrowsing.userid = ##c1.userid AND ##c1.category = 'Medical'
GO
UPDATE CrossBrowsing set CrossBrowsing.lifestyle = ##c1.[Number of Visits]
FROM ##c1
WHERE CrossBrowsing.userid = ##c1.userid AND ##c1.category = 'Lifestyle'
GO
UPDATE CrossBrowsing set CrossBrowsing.epharmacy = ##c1.[Number of Visits]
FROM ##c1
WHERE CrossBrowsing.userid = ##c1.userid AND ##c1.category = 'E-pharmacy'
GO

SELECT COUNT(lifestyle) ul
      ,SUM(lifestyle) vl
      ,COUNT(epharmacy) ue
      ,SUM(epharmacy) ve
FROM data.dbo.CrossBrowsing
WHERE medical IS NOT NULL
GO


-- [医疗]Create labels(Platform & Channel)
ALTER TABLE [data].[dbo].[health_records]
ADD platform varchar(20) null  
GO
ALTER TABLE [data].[dbo].[health_records]
ADD channel varchar(20) null
GO

-- platform
UPDATE [data].[dbo].[health_records]
SET platform =
    CASE
        WHEN agent LIKE '%Apache-HttpClient%' THEN 'android'
        WHEN agent LIKE '%Dalvik%' THEN 'android'
        WHEN agent LIKE '%Darwin%' THEN 'iphone'
        WHEN agent LIKE '%iPhone%' THEN 'iphone'
        WHEN agent LIKE '%android%' THEN 'android'
        WHEN agent LIKE '%Mozilla/% (i%' THEN 'iphone'
        WHEN agent LIKE '%Mozilla/% (L%' THEN 'android'
        WHEN agent LIKE '%okhttp%' THEN 'android'
        WHEN agent LIKE '%Xiaomi%' THEN 'android'
        WHEN agent LIKE '%Macintosh%' THEN 'iphone'
        WHEN agent LIKE '%Phoenix%' THEN 'android'
    END
GO

-- channel
UPDATE [data].[dbo].[health_records]
SET channel =
    CASE
        WHEN agent LIKE '%Apache-HttpClient%' THEN 'app'
        WHEN agent LIKE '%Phoenix%' THEN 'app'
        WHEN agent LIKE '%okhttp%' THEN 'app'
        WHEN agent LIKE '%Dalvik%' THEN 'app'
        WHEN agent LIKE '%Darwin%' THEN 'app'
        WHEN agent LIKE 'QQ%' THEN 'browser'
        WHEN agent LIKE 'Xiaomi%' THEN 'browser'
        WHEN agent LIKE '%app%' THEN 'app'
        WHEN agent = 'Android/Volley' THEN 'app'
        WHEN agent = 'Android/retrofit' THEN 'app'
        WHEN agent LIKE 'Mozilla%Linux%Version%' THEN 'app'
        WHEN agent LIKE 'Mozilla%Linux%' THEN 'browser'
        WHEN agent LIKE 'Mozilla%iPhone%Version%' THEN 'browser'
        WHEN agent LIKE 'Mozilla%iPhone%' THEN 'app'
    END
GO


-- [医疗]T-test
-- Number of Visits
SELECT userid
      ,platform
      ,COUNT(url) AS [Number of Visits]
FROM [data].[dbo].[health_records]
GROUP BY userid, platform
HAVING platform IS NOT NULL
ORDER BY userid, platform
GO

SELECT userid
      ,channel
      ,COUNT(url) AS [Number of Visits]
FROM [data].[dbo].[health_records]
GROUP BY userid, channel
HAVING channel IS NOT NULL
ORDER BY userid, channel
GO

SELECT r.userid
      ,u.gender
      ,u.consumption
      ,COUNT(r.url) AS [Number of Visits]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[user] u
ON r.userid = u.userid
GROUP BY r.userid, u.gender, u.consumption
ORDER BY r.userid
GO

-- Intensity of Use
SELECT userid
      ,date
      ,platform
      ,COUNT(url) AS [Use Intensity]
FROM [data].[dbo].[health_records]
GROUP BY userid, date, platform
HAVING platform IS NOT NULL
ORDER BY userid, date, platform
GO

SELECT userid
      ,date
      ,channel
      ,COUNT(url) AS [Use Intensity]
FROM [data].[dbo].[health_records]
GROUP BY userid, date, channel
HAVING channel IS NOT NULL
ORDER BY userid, date, channel
GO

SELECT r.userid
      ,r.date
      ,u.gender
      ,u.consumption
      ,COUNT(r.url) AS [Use Intensity]
FROM [data].[dbo].[health_records] r
JOIN [data].[dbo].[user] u
ON r.userid = u.userid
GROUP BY r.userid, r.date, u.gender, u.consumption
ORDER BY r.userid, r.date
GO






