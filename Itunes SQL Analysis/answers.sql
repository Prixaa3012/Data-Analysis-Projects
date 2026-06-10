select invoice_date from invoice;

ALTER TABLE invoice
ALTER COLUMN invoice_date TYPE date
USING invoice_date::date;

-- Which customers have spent the most money on music?

select c.first_name, sum(i.total) from customer c
join invoice i on c.customer_id = i.customer_id
group by c.first_name 
order by sum(i.total) desc limit 1;


-- What is the average customer lifetime value?

SELECT ROUND(AVG(customer_total), 2) AS avg_customer_lifetime_value
FROM (SELECT c.customer_id, SUM(i.total) AS customer_total
FROM customer c JOIN invoice i ON c.customer_id = i.customer_id 
GROUP BY c.customer_id) 
AS customer_spending;


-- How many customers have made repeat purchases versus one-time purchases?

SELECT CASE WHEN purchase_count = 1 THEN 'One-time Purchase'
ELSE 'Repeat Purchase'
END AS customer_type,
COUNT(*) AS number_of_customers
FROM (SELECT c.customer_id, 
COUNT(i.invoice_id) AS purchase_count
FROM customer c
JOIN invoice i 
ON c.customer_id = i.customer_id
GROUP BY c.customer_id) 
AS customer_purchases
GROUP BY customer_type;


-- Which country generates the most revenue per customer?

SELECT c.country, ROUND(SUM(i.total) / COUNT(DISTINCT c.customer_id), 2) 
AS revenue_per_customer
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.country
ORDER BY revenue_per_customer DESC
LIMIT 1;


-- Which customers haven't made a purchase in the last 6 months?

SELECT c.customer_id, c.first_name, c.last_name, c.email,
MAX(i.invoice_date) AS last_purchase_date FROM customer c
LEFT JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.email
HAVING MAX(i.invoice_date) IS NULL 
OR MAX(i.invoice_date) < CURRENT_DATE - INTERVAL '6 months'
ORDER BY c.customer_id NULLS FIRST;


-- What are the monthly revenue trends for the last two years?

SELECT TO_CHAR(invoice_date, 'YYYY-MM') AS year_month,
ROUND(SUM(total), 2) AS monthly_revenue
FROM invoice
WHERE invoice_date >= ( SELECT MAX(invoice_date) - INTERVAL '2 years'
FROM invoice)
GROUP BY TO_CHAR(invoice_date, 'YYYY-MM')
ORDER BY year_month;


-- What is the average value of an invoice (purchase)?

SELECT ROUND(AVG(total), 2) AS average_invoice_value FROM invoice;


-- Which payment methods are used most frequently?

-- How much revenue does each sales representative contribute?

select distinct(support_rep_id) from customer;

select e.first_name, e.last_name, sum(i.total) from employee e
join customer c on c.support_rep_id = e.employee_id
join invoice i on c.customer_id = i.customer_id
group by e.first_name, e.last_name
order by sum(i.total) desc;


-- Which months or quarters have peak music sales?

select TRIM(TO_CHAR(invoice_date, 'Month')) as month, 
ROUND(SUM(total), 2) AS monthly_revenue FROM invoice
group by month
order by monthly_revenue
desc limit 3;


-- Which tracks generated the most revenue?

select t.name, sum(i.unit_price * i.quantity) as revenue from invoice_line i
join track t on i.track_id = t.track_id
group by t.name
order by revenue desc limit 5;


-- Which albums or playlists are most frequently included in purchases?

select a.title, count(i.*) as albumssold from album a
join track t on a.album_id = t.album_id 
join invoice_line il on il.track_id=t.track_id
join invoice i on i.invoice_id = il.invoice_id
group by a.title
order by albumssold desc limit 5;


-- Are there any tracks or albums that have never been purchased?

select a.title, count(i.*) as albumssold from album a
join track t on a.album_id = t.album_id 
join invoice_line il on il.track_id=t.track_id
join invoice i on i.invoice_id = il.invoice_id
group by a.title
having count(i.*) = 0;

select t.name, count(i.*) as albumssold from track t
join invoice_line il on il.track_id=t.track_id
join invoice i on i.invoice_id = il.invoice_id
group by t.name
having count(i.*) = 0;


-- What is the average price per track across different genres?

select g.name, round(avg(unit_price), 2) from genre g
join track t on t.genre_id = g.genre_id
group by g.name;

select unit_price from track;


-- How many tracks does the store have per genre 
-- and how does it correlate with sales?

-- Who are the top 5 highest-grossing artists?

select ar.name, sum(i.unit_price * i.quantity) as revenue from artist ar
join album al on al.artist_id = ar.artist_id
join track t on t.album_id = al.album_id
join invoice_line i on i.track_id = t.track_id
group by ar.name
order by revenue
desc limit 5;


-- Which music genres are most popular in terms of:
-- Number of tracks sold
-- Total revenue

select g.name, sum(i.quantity) as units_sold from genre g
join track t on t.genre_id = g.genre_id
join invoice_line i on i.track_id = t.track_id
group by g.name order by units_sold desc limit 5;

select g.name, sum(i.unit_price * i.quantity) as revenue from genre g
join track t on t.genre_id = g.genre_id
join invoice_line i on i.track_id = t.track_id
group by g.name order by revenue desc limit 5;


-- Are certain genres more popular in specific countries?

with country_genre_revenue as (
select c.country, g.name as genre, 
sum(il.unit_price * il.quantity) as revenue from invoice i
join customer c on i.customer_id = c.customer_id
join invoice_line il on i.invoice_id = il.invoice_id
join track t on il.track_id = t.track_id
join genre g on t.genre_id = g.genre_id
group by c.country, g.name )
select country, genre, ROUND(revenue, 2) as revenue
from (select *, row_number() over ( partition by country 
order by revenue desc) as rn
from country_genre_revenue) ranked
where rn = 1
order by country;


-- Which employees (support representatives) 
-- are managing the highest-spending customers?

WITH customer_spending AS (
SELECT c.customer_id, c.support_rep_id, SUM(i.total) AS total_spent
FROM customer c JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY c.customer_id, c.support_rep_id)
SELECT e.employee_id, e.first_name, e.last_name, 
ROUND(SUM(cs.total_spent), 2) AS total_managed_revenue
FROM customer_spending cs 
JOIN employee e ON cs.support_rep_id = e.employee_id
GROUP BY e.employee_id, e.first_name, e.last_name
ORDER BY total_managed_revenue DESC;


-- What is the average number of customers per employee?

SELECT ROUND(AVG(customer_count), 2) AS avg_customers_per_employee FROM (
SELECT support_rep_id, COUNT(customer_id) AS customer_count FROM customer
GROUP BY support_rep_id
) t;


-- Which employee regions bring in the most revenue?

SELECT e.country, 
ROUND(SUM(i.total), 2) AS total_revenue FROM employee e 
JOIN customer c ON e.employee_id = c.support_rep_id
JOIN invoice i ON c.customer_id = i.customer_id
GROUP BY e.country
ORDER BY total_revenue DESC limit 1;


-- Which countries or cities have the highest number of customers?

select country, count(*) as customers from customer
group by country order by customers desc limit 5;

select city, count(*) as customers from customer
group by city order by customers desc limit 5;


-- How does revenue vary by region?

select c.country, ROUND(SUM(i.total), 2) AS revenue from customer c
join invoice i on i.customer_id = c.customer_id
group by c.country order by revenue desc;


-- What is the distribution of purchase frequency per customer?

select purchase_count, count(*) as number_of_customers from (
select c.customer_id, count(i.invoice_id) as purchase_count
from customer c 
left join invoice i on c.customer_id = i.customer_id
group by c.customer_id) t
group by purchase_count
order by purchase_count;	


-- How long is the average time between customer purchases?

with customer_intervals as (
select customer_id, invoice_date, invoice_date - lag(invoice_date) 
over ( partition by customer_id 
order by invoice_date) as days_between
from invoice)
select round(avg(days_between), 2) as avg_days_between_purchases
from customer_intervals
where days_between is not null;


-- What percentage of customers purchase tracks from more than one genre?

with customer_genres as (
select i.customer_id, count(distinct t.genre_id) as genre_count
from invoice i
join invoice_line il on i.invoice_id = il.invoice_id
join track t on il.track_id = t.track_id
group by i.customer_id)
select round(100.0 * count(*) filter (where genre_count > 1)/count(*),2) as percentage_multi_genre_customers
from customer_genres;


-- What are the most common combinations of tracks purchased together?

select t1.name as track_1,t2.name as track_2, count(*) as times_purchased_together
from invoice_line il1
join invoice_line il2 on il1.invoice_id = il2.invoice_id and il1.track_id < il2.track_id
join track t1 on il1.track_id = t1.track_id
join track t2 on il2.track_id = t2.track_id
group by t1.name, t2.name
order by times_purchased_together desc
limit 10; 


-- Are there pricing patterns that lead to higher or lower sales?

select unit_price, sum(quantity) as total_units_sold, 
round(sum(unit_price * quantity), 2) as total_revenue
from invoice_line
group by unit_price
order by unit_price;


-- 
