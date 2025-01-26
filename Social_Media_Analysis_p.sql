-- SOCIAL MEDIA ANALYSIS

-----------
-- objective
-----------

-- 1. Are there any tables with duplicate or missing null values? If so, how would you handle them?

-- checking for duplicates
SELECT comment_text, user_id, photo_id, created_at
FROM comments 
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1;

SELECT follower_id, followee_id
FROM follows 
GROUP BY  1,2
HAVING COUNT(*) > 1;

SELECT user_id, photo_id
FROM likes
GROUP BY 1,2
HAVING COUNT(*) > 1;

SELECT photo_id, tag_id
FROM photo_tags
GROUP BY 1,2
HAVING COUNT(*) > 1;

SELECT image_url, user_id, created_dat
FROM photos
GROUP BY 1,2,3
HAVING COUNT(*) > 1;

SELECT tag_name, created_at
FROM tags
GROUP BY 1,2
HAVING COUNT(*) > 1;

SELECT username, created_at 
FROM users
GROUP BY 1,2
HAVING COUNT(*) > 1;

-- checking for null
SELECT * FROM comments 
WHERE id IS NULL OR comment_text IS NULL OR user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;

SELECT * FROM follows 
WHERE follower_id IS NULL OR followee_id IS NULL OR created_at IS NULL;

SELECT * FROM likes 
WHERE user_id IS NULL OR photo_id IS NULL OR created_at IS NULL;

SELECT * FROM photo_tags 
WHERE photo_id IS NULL OR tag_id IS NULL;

SELECT * FROM photos
WHERE id IS NULL OR image_url IS NULL OR user_id IS NULL OR created_dat IS NULL;

SELECT * FROM tags 
WHERE id IS NULL OR tag_name IS NULL OR created_at IS NULL;

SELECT * FROM users 
WHERE id IS NULL OR username IS NULL OR created_at IS NULL;



-- 2. What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

SELECT u.id AS user_id, u.username, 
COUNT(DISTINCT p.id) AS posts_count, 
CASE 
    WHEN COUNT(DISTINCT p.id) = 0 THEN 'Zero Posts' 
    WHEN COUNT(DISTINCT p.id) <= MAX(COUNT(DISTINCT p.id)) OVER() / 3 THEN 'Low Posts'
    WHEN COUNT(DISTINCT p.id) <= 2 * MAX(COUNT(DISTINCT p.id)) OVER() / 3 THEN 'Medium Posts'
    ELSE 'High Posts' 
END AS posts_segment,
COUNT(DISTINCT l.photo_id) AS likes_count, 
CASE 
    WHEN COUNT(DISTINCT l.photo_id) = 0 THEN 'Zero Likes'
    WHEN COUNT(DISTINCT l.photo_id) <= MAX(COUNT(DISTINCT l.photo_id)) OVER() / 3 THEN 'Low Likes'
    WHEN COUNT(DISTINCT l.photo_id) <= 2 * MAX(COUNT(DISTINCT l.photo_id)) OVER() / 3 THEN 'Medium Likes'
    ELSE 'High Likes' 
END AS likes_segment,
COUNT(DISTINCT c.id) AS comments_count,
CASE 
    WHEN COUNT(DISTINCT c.id) = 0 THEN 'Zero Comments'
    WHEN COUNT(DISTINCT c.id) <= MAX(COUNT(DISTINCT c.id)) OVER() / 3 THEN 'Low Comments'
    WHEN COUNT(DISTINCT c.id) <= 2 * MAX(COUNT(DISTINCT c.id)) OVER() / 3 THEN 'Medium Comments'
    ELSE 'High Comments' 
END AS comments_segment
FROM users u 
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON u.id = l.user_id
LEFT JOIN comments c ON u.id = c.user_id
GROUP BY 1, 2;



-- 3. Calculate the average number of tags per post (photo_tags and photos tables).

SELECT ROUND(AVG(tags_per_post), 2) AS avg_num_tags_per_post
FROM (
    SELECT p.id AS post, COUNT(pt.tag_id) AS tags_per_post
    FROM photos p 
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    GROUP BY 1
) dt;



-- 4. Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.

WITH cte AS (
    SELECT u.id AS user_id, u.username,
    (COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) AS engagement,
    (COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) * 100 / SUM((COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id))) OVER() AS engagement_rate, 
    DENSE_RANK() OVER(ORDER BY (COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) DESC) AS highest_engagements
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY 1
)
SELECT user_id, username, engagement_rate, highest_engagements AS ranking
FROM cte 
WHERE highest_engagements IN (1, 2, 3)
ORDER BY 4, 1;



-- 5. Which users have the highest number of followers and followings?

WITH cte AS (
    SELECT u.username, f.followee_id, COUNT(follower_id) AS num_followers
    FROM follows f 
    JOIN users u ON u.id = f.followee_id
    GROUP BY 1, 2
)
SELECT username, followee_id, num_followers, COUNT(followee_id) OVER() AS count_of_followee_with_highest_followers
FROM cte 
WHERE num_followers = (SELECT MAX(num_followers) FROM cte);

WITH cte AS (
    SELECT u.username, follower_id, COUNT(followee_id) AS num_followees
    FROM follows f
    JOIN users u ON u.id = f.follower_id
    GROUP BY 1, 2
)
SELECT username, follower_id, num_followees, COUNT(follower_id) OVER() AS count_of_follower_with_highest_followers
FROM cte
WHERE num_followees = (SELECT MAX(num_followees) FROM cte);



-- 6. Calculate the average engagement rate (likes, comments) per post for each user.

WITH cte AS (
    SELECT u.id AS user_id, u.username, p.id AS post_id, (COUNT(DISTINCT l.user_id) + COUNT(DISTINCT c.id)) AS total_engagement
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON P.ID = l.photo_id
    LEFT JOIN comments c ON P.ID = c.photo_id
    GROUP BY 1, 2, 3
)
SELECT DISTINCT user_id, username, 
ROUND(AVG(total_engagement) OVER(PARTITION BY user_id), 2) AS avg_engagement_per_post_for_each_user
FROM cte
ORDER BY 3 DESC;



-- 7. Get the list of users who have never liked any post (users and likes tables).

SELECT username
FROM (
	SELECT u.id as user_id, u.username, COUNT(DISTINCT l.photo_id) AS likes_count
	FROM users u 
	LEFT JOIN photos p on u.id = p.user_id
	LEFT JOIN likes l on u.id = l.user_id
	GROUP BY 1, 2
	HAVING COUNT(DISTINCT l.photo_id) = 0
) dt 
ORDER BY 1;



-- 8. How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?

SELECT id AS user_id, tag_name, tags_count 
FROM (
	SELECT u.id, t.tag_name, COUNT(t.tag_name) AS tags_count,
	DENSE_RANK() OVER(PARTITION BY tag_name ORDER BY COUNT(t.tag_name) DESC) AS ranking
	FROM users u
	JOIN photos p on u.id = p.user_id
	JOIN photo_tags pt on p.id = pt.photo_id
	JOIN tags t on pt.tag_id = t.id
	GROUP BY 1, 2
) AS dt
WHERE ranking = 1;
     


-- 9. Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? 
-- How can this information guide content creation and curation strategies?

SELECT p.id AS photo_id, p.image_url AS photo_url, COUNT(DISTINCT l.user_id) AS likes_count, COUNT(DISTINCT c.id) AS comments_count
FROM photos p
LEFT JOIN likes l on p.id = l.photo_id
LEFT JOIN comments c on p.id = c.photo_id
GROUP BY 1
ORDER BY 3 DESC;

	-- we only have data on images. So, we can check user activity levels on photos only.



-- 10. Calculate the total number of likes, comments, and photo tags for each user.

SELECT user_id, username, SUM(likes_count) AS likes_count, SUM(comments_count) AS comments_count, SUM(tags_count) AS tags_count
FROM (
	SELECT u.id AS user_id, u.username, p.id AS photo_id, COUNT(DISTINCT l.user_id) AS likes_count, COUNT(DISTINCT c.id) AS comments_count, COUNT(DISTINCT tag_id) AS tags_count
	FROM users u 
	LEFT JOIN photos p ON u.id = p.user_id
	LEFT JOIN likes l ON p.id = l.photo_id
	LEFT JOIN comments c ON p.id = c.photo_id
	LEFT JOIN photo_tags pt ON p.id = pt.photo_id
	GROUP BY 1, 2, 3
) dt
GROUP BY 1, 2;



-- 11. Rank users based on their total engagement (likes, comments, shares) over a month.

SELECT DATE_FORMAT(p.created_dat, '%Y-%m') AS `month`, 
u.id AS user_id, 
u.username, 
(COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) AS total_engagement,
RANK() OVER(PARTITION BY DATE_FORMAT(p.created_dat, '%Y-%m') ORDER BY (COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) DESC) AS engagement_rank
FROM users u 
LEFT JOIN photos p ON u.id = p.user_id
LEFT JOIN likes l ON u.id = l.user_id AND p.created_dat = l.created_at
LEFT JOIN comments c ON u.id = c.user_id AND p.created_dat = c.created_at
WHERE DATE_FORMAT(p.created_dat, '%Y-%m') IS NOT NULL
GROUP BY 1, 2, 3;



-- 12. Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.

WITH tag_likes AS (
    SELECT t.id AS tag_id,
    tag_name,
    pt.photo_id, 
    COUNT(DISTINCT l.user_id) AS total_likes,
    AVG(COUNT(DISTINCT l.user_id)) OVER(PARTITION BY t.id) AS avg_likes
    FROM tags t 
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    JOIN likes l ON l.photo_id = pt.photo_id
    GROUP BY 1, 2, 3
)
SELECT DISTINCT tag_id, tag_name as hashtag
FROM tag_likes
WHERE avg_likes IN (SELECT MAX(avg_likes) FROM tag_likes)
ORDER BY 1;



-- 13. Retrieve the users who have started following someone after being followed by that person.

SELECT f1.follower_id AS followed_back, f1.followee_id AS original_follower
FROM follows f1
JOIN follows f2 
  ON f1.follower_id = f2.followee_id  
  AND f1.followee_id = f2.follower_id 
  AND f1.created_at > f2.created_at;




-----------
-- subjective
-----------

-- 1. Based on user engagement and activity levels, which users would you consider the most loyal or valuable? 
-- How would you reward or incentivize these users?

WITH cte AS (
    SELECT u.id AS user_id, 
           u.username, 
           COUNT(DISTINCT p.id) AS posts_count, 
           COUNT(DISTINCT l.photo_id) AS likes_count, 
           COUNT(DISTINCT c.id) AS comments_count,
           COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) AS user_engagement, 
           DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) DESC) AS drank
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY 1, 2
)
SELECT user_id, username, posts_count, likes_count, comments_count, user_engagement
FROM cte 
WHERE drank BETWEEN 1 AND 5 AND posts_count > 0;



-- 2. For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

WITH cte AS (
    SELECT u.id AS user_id, 
           u.username, 
           COUNT(DISTINCT p.id) AS posts_count, 
           COUNT(DISTINCT l.photo_id) AS likes_count, 
           COUNT(DISTINCT c.id) AS comments_count,
           COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id) AS user_engagement, 
           DENSE_RANK() OVER(ORDER BY COUNT(DISTINCT p.id) + COUNT(DISTINCT l.photo_id) + COUNT(DISTINCT c.id)) AS drank
    FROM users u 
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN likes l ON u.id = l.user_id
    LEFT JOIN comments c ON u.id = c.user_id
    GROUP BY 1, 2
)
SELECT user_id, username, posts_count, likes_count, comments_count, user_engagement
FROM cte 
WHERE drank BETWEEN 1 AND 10
ORDER BY 1;

   
   
-- 3. Which hashtags or content topics have the highest engagement rates? How can this information guide content strategy and ad campaigns?

WITH count_likes AS (
    SELECT t.tag_name, COUNT(l.user_id) AS likes_count
    FROM tags t
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN likes l ON pt.photo_id = l.photo_id
    GROUP BY 1
),
count_posts AS (
    SELECT t.tag_name, COUNT(p.id) AS posts_count
    FROM tags t 
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN photos p ON pt.photo_id = p.id
    GROUP BY 1
), 
count_comments AS (
    SELECT t.tag_name, COUNT(c.id) AS comments_count
    FROM tags t 
    LEFT JOIN photo_tags pt ON t.id = pt.tag_id
    LEFT JOIN comments c ON pt.photo_id = c.photo_id
    GROUP BY 1
)
SELECT cl.tag_name, 
       cl.likes_count + cp.posts_count + cc.comments_count AS engagement,
       ROUND((cl.likes_count + cp.posts_count + cc.comments_count) * 100 / SUM(cl.likes_count + cp.posts_count + cc.comments_count) OVER(), 2) AS engagement_rate
FROM count_likes cl
JOIN count_posts cp ON cl.tag_name = cp.tag_name
JOIN count_comments cc ON cl.tag_name = cc.tag_name
ORDER BY 2 DESC 
LIMIT 5;



-- 4. Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? 
-- How can these insights inform targeted marketing campaigns?

SELECT
    WEEKDAY(p.created_dat) AS day_of_week, 
    EXTRACT(HOUR FROM p.created_dat) AS hour_of_day,       
    COUNT(DISTINCT p.id) AS total_photos_posted,         
    COUNT(DISTINCT l.user_id) AS total_likes_received,     
    COUNT(DISTINCT c.id) AS total_comments_made         
FROM photos p
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
GROUP BY
    day_of_week,
    hour_of_day
ORDER BY
    day_of_week,
    hour_of_day;


SELECT
    DAYNAME(u.created_at) AS day_of_week, 
    EXTRACT(HOUR FROM u.created_at) AS hour_of_day,       
    COUNT(DISTINCT p.id) AS total_photos_posted,         
    COUNT(DISTINCT l.user_id) AS total_likes_received,     
    COUNT(DISTINCT c.id) AS total_comments_made         
FROM users u 
LEFT JOIN photos p
	ON u.id = p.user_id
LEFT JOIN likes l
    ON p.id = l.photo_id
LEFT JOIN comments c
    ON p.id = c.photo_id
WHERE EXTRACT(HOUR FROM p.created_dat) is not null 
GROUP BY
    day_of_week,
    hour_of_day
ORDER BY
    day_of_week,
    hour_of_day;



-- 5. Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns?
-- How would you approach and collaborate with these influencers?

WITH cte AS (
    SELECT username, engagement_rate, follower_count,
           (engagement_rate * 0.6 + follower_count * 0.4) AS weighted_score
    FROM ( 
        SELECT u.id AS user_id, u.username, 
               (COALESCE(posts_count, 0) + COALESCE(likes_count, 0) + COALESCE(comments_count, 0)) * 100 / 
               SUM((COALESCE(posts_count, 0) + COALESCE(likes_count, 0) + COALESCE(comments_count, 0))) OVER() AS engagement_rate,
               follower_count
        FROM users u
        LEFT JOIN (
            SELECT user_id, COUNT(*) AS posts_count
            FROM photos
            GROUP BY user_id
        ) p ON u.id = p.user_id
        LEFT JOIN (
            SELECT user_id, COUNT(DISTINCT photo_id) AS likes_count
            FROM likes
            GROUP BY user_id
        ) l ON u.id = l.user_id
        LEFT JOIN (
            SELECT user_id, COUNT(*) AS comments_count
            FROM comments
            GROUP BY user_id
        ) c ON u.id = c.user_id
        LEFT JOIN (
            SELECT followee_id, COUNT(DISTINCT follower_id) AS follower_count
            FROM follows
            GROUP BY followee_id
        ) f2 ON u.id = f2.followee_id
    ) dt
) 
SELECT username, engagement_rate, follower_count, weighted_score
FROM cte 
WHERE follower_count = (select max(follower_count) from cte) and engagement_rate > 0
ORDER BY weighted_score DESC;

 
 
 -- 6. Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?

WITH user_engagement AS (
    SELECT 
        u.id AS user_id, 
        u.username, 
        COALESCE(p.engagement, 0) + COALESCE(l.engagement, 0) + COALESCE(c.engagement, 0) AS engagement,
        COALESCE(t.tag_count, 0) AS tag_count
    FROM 
        users u
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT id) AS engagement
        FROM photos
        GROUP BY user_id
    ) p ON u.id = p.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT photo_id) AS engagement
        FROM likes
        GROUP BY user_id
    ) l ON u.id = l.user_id
    LEFT JOIN (
        SELECT user_id, COUNT(DISTINCT id) AS engagement
        FROM comments
        GROUP BY user_id
    ) c ON u.id = c.user_id
    LEFT JOIN (
		SELECT u.id AS user_id, 
        COUNT(DISTINCT t.tag_name) AS tag_count
        FROM
        users u
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    LEFT JOIN tags t ON pt.tag_id = t.id
    GROUP BY u.id
    ) t ON u.id = t.user_id
),
global_max AS (
    SELECT 
        MAX(engagement) AS max_engagement, 
        MAX(tag_count) AS max_tag_count
    FROM user_engagement
),
user_tags AS (
    SELECT
        u.id AS user_id,
        group_concat(t.tag_name) AS tags
    FROM
        users u
    LEFT JOIN photos p ON u.id = p.user_id
    LEFT JOIN photo_tags pt ON p.id = pt.photo_id
    LEFT JOIN tags t ON pt.tag_id = t.id
    GROUP BY u.id
),
user_segments AS (
    SELECT
        e.user_id,
        e.username,
        e.engagement,
        e.tag_count,
        t.tags,
        CASE
            WHEN e.engagement < gm.max_engagement / 3 AND e.tag_count < gm.max_tag_count / 3 THEN 'Low Engagement'
            WHEN e.engagement < 2 * gm.max_engagement / 3 AND e.tag_count < 2 * gm.max_tag_count / 3 THEN 'Moderate Engagement'
            ELSE 'High Engagement'
        END AS engagement_segment
    FROM user_engagement e
    LEFT JOIN user_tags t ON e.user_id = t.user_id
    CROSS JOIN global_max gm  -- Cross join to ensure you can use the global maximums
    GROUP BY e.user_id, e.username, e.engagement, e.tag_count, t.tags, gm.max_engagement, gm.max_tag_count
)
SELECT *
FROM user_segments
WHERE tag_count > 0 AND tags IS NOT NULL and engagement_segment in ('High Engagement', 'Low Engagement')
ORDER BY engagement_segment, engagement DESC;



															-- END --