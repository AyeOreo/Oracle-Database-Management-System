// SQL Query Report #1
// Total Number of Ticket Bookings and Total Payment Amount per Event
WITH Ticket_Summary AS ( -- aggregates ticket data by event and calculates the different types of revenues
    SELECT EventID,
        COUNT(TicketID) AS Total_Bookings,
        SUM(Ticket_Price * Number_of_Tickets) AS Total_Payment_Amount,
        SUM(CASE WHEN Ticket_Type = 'VIP' THEN Ticket_Price * Number_of_Tickets ELSE 0 END) AS VIP_Revenue,
        SUM(CASE WHEN Ticket_Type = 'Accessible' THEN Ticket_Price * Number_of_Tickets ELSE 0 END) AS Accessible_Revenue,
        SUM(CASE WHEN Ticket_Type = 'Seated' THEN Ticket_Price * Number_of_Tickets ELSE 0 END) AS Seated_Revenue,
        SUM(CASE WHEN Ticket_Type = 'Standing' THEN Ticket_Price * Number_of_Tickets ELSE 0 END) AS Standing_Revenue
    FROM Tickets  GROUP BY EventID
),
Event_Details AS ( -- joins the Events and Venue entities to display event and venue names
    SELECT e.EventID, e.Event_Name, e.Event_Datetime, v.Venue_Name
    FROM Events e
    JOIN Venue v ON e.VenueID = v.VenueID
)
SELECT 
    ts.EventID,
    ed.Event_Name,
    ed.Event_Datetime,
    ed.Venue_Name,
    ts.Total_Bookings,
    ts.Total_Payment_Amount,
    ts.VIP_Revenue,
    ts.Accessible_Revenue,
    ts.Seated_Revenue,
    ts.Standing_Revenue,
    CASE -- segregates total revenue per event into categories for further financial review
        WHEN ts.Total_Payment_Amount > 20000 THEN 'High Revenue'
        WHEN ts.Total_Payment_Amount BETWEEN 10000 AND 20000 THEN 'Medium Revenue'
        ELSE 'Low Revenue'
    END AS Revenue_Category
FROM Ticket_Summary ts
JOIN Event_Details ed ON ts.EventID = ed.EventID
ORDER BY ts.Total_Payment_Amount DESC;

// SQL Report #2
// Aggregates customer support queries by query type and customer type and classifies each by urgency based on percentage of unresolved queries and filters cases where more than 20% of queries are unresolved
WITH Support_Query_Summary AS (
    SELECT 
        css.Query_Type, 
        c.Customer_Type, 
        COUNT(*) AS Total_Queries,
        SUM(CASE WHEN css.Query_Status = 'Pending' THEN 1 ELSE 0 END) AS Unresolved_Queries
    FROM 
        Customer_Support_Service css
    JOIN 
        Customers c ON css.CustomerID = c.CustomerID
    GROUP BY 
        css.Query_Type, c.Customer_Type
    HAVING 
        SUM(CASE WHEN css.Query_Status = 'Pending' THEN 1 ELSE 0 END) > 0 
),
Percentage_Unresolved AS (
    SELECT 
        sqs.Query_Type, 
        sqs.Customer_Type, 
        sqs.Total_Queries, 
        sqs.Unresolved_Queries,
        ROUND((sqs.Unresolved_Queries / sqs.Total_Queries) * 100, 2) AS Unresolved_Percentage
    FROM 
        Support_Query_Summary sqs
    HAVING 
        ROUND((sqs.Unresolved_Queries / sqs.Total_Queries) * 100, 2) > 20 
)
SELECT 
    pu.Query_Type, 
    pu.Customer_Type, 
    pu.Total_Queries, 
    pu.Unresolved_Queries, 
    pu.Unresolved_Percentage,
    CASE 
        WHEN pu.Unresolved_Percentage >= 50 THEN 'Urgent'
        WHEN pu.Unresolved_Percentage >= 30 THEN 'Moderate' 
        ELSE 'Normal'
    END AS Urgency_Status
FROM 
    Percentage_Unresolved pu
ORDER BY 
    pu.Unresolved_Percentage DESC, pu.Query_Type;    
    
// SQL Query Report #3
// Subqueries to identify the highest revenue from different ticket types at different events so respective events can optimize ticket allocation by allocating more tickets from low revenue earning tickets to high revenue earning tickets 
SELECT 
    ttr.EventID, 
    e.Event_Name, 
    ttr.Ticket_Type, 
    ttr.Revenue 
FROM 
    (SELECT 
        t.EventID, 
        t.Ticket_Type, 
        SUM(t.Ticket_Price) AS Revenue 
     FROM 
        Tickets t 
     GROUP BY 
        t.EventID, t.Ticket_Type) ttr 
JOIN 
    Events e ON ttr.EventID = e.EventID 
ORDER BY 
    ttr.Revenue DESC;

// SQL Query Report #4
// Identifying types of Customers and their behaviour
WITH Customers_With_Interactions AS (
    SELECT 
        css.CustomerID
    FROM 
        Customer_Support_Service css
    WHERE 
        css.Query_Type = 'Billing'
    INTERSECT 
    SELECT 
        p.CustomerID
    FROM 
        Purchases p
),
Customer_Details AS (
    SELECT
        c.CustomerID,
        c.Name,
        c.Email,
        CASE 
            WHEN gc.CustomerID IS NOT NULL THEN 'General'
            WHEN dc.CustomerID IS NOT NULL THEN 'Disabled'
            ELSE 'Unknown'
        END AS Member_Type,
        COUNT(css.QueryID) AS Total_Queries,
        COUNT(p.PurchaseID) AS Total_Purchases,
        SUM(p.Total_Amount) AS Total_Spent,
        'Billing' AS Query_Type
    FROM 
        Customers c
    LEFT JOIN 
        GeneralCustomers gc ON c.CustomerID = gc.CustomerID
    LEFT JOIN 
        DisabledCustomers dc ON c.CustomerID = dc.CustomerID
    LEFT JOIN 
        Customer_Support_Service css ON c.CustomerID = css.CustomerID AND css.Query_Type = 'Billing'
    LEFT JOIN 
        Purchases p ON c.CustomerID = p.CustomerID
    GROUP BY 
        c.CustomerID, c.Name, c.Email, gc.CustomerID, dc.CustomerID
)
SELECT 
    cwi.CustomerID,
    cd.Name,
    cd.Email,
    cd.Member_Type,
    cd.Total_Queries,
    cd.Total_Purchases,
    cd.Total_Spent,
    cd.Query_Type
FROM 
    Customers_With_Interactions cwi
JOIN 
    Customer_Details cd ON cwi.CustomerID = cd.CustomerID
ORDER BY 
    cd.Total_Spent DESC;

// SQL Query Report #5
// Event details to help the company plan resources and logistics for each event
SELECT   
    a.Artist_Name,   
    e.Event_Name,   
    e.Event_Datetime,   
    e.Event_Duration,   
    v.Venue_Name,   
    v.Seating_Capacity,  
    COALESCE(SUM(t.Number_of_Tickets), 0) AS Total_Tickets_Purchased 
FROM   
    Artists a  
LEFT OUTER JOIN   
    Events e ON a.ArtistID = e.ArtistID  
RIGHT OUTER JOIN   
    Venue v ON e.VenueID = v.VenueID 
LEFT OUTER JOIN  
    Tickets t ON e.EventID = t.EventID 
GROUP BY   
    a.Artist_Name,   
    e.Event_Name,   
    e.Event_Datetime,   
    e.Event_Duration,   
    v.Venue_Name,   
    v.Seating_Capacity 
ORDER BY  
    a.Artist_Name, e.Event_Name;

// SQL Query Report #6
// Customer details and total spending to identify high-value customers and assess marketing/customer retention strategies 
SELECT  
    c.CustomerID,  
    c.Name,  
    COALESCE(gc.Member_Level, dc.Member_Level) AS Membership_Status,  
    CASE  
        WHEN gc.CustomerID IS NOT NULL THEN 'General' 
        WHEN dc.CustomerID IS NOT NULL THEN 'Disabled' 
        ELSE 'Unknown' 
    END AS Customer_Type, 
    SUM(p.Total_Amount) AS Total_Spent, 
    CASE  
        WHEN SUM(p.Total_Amount) < 500 THEN 'Low' 
        WHEN SUM(p.Total_Amount) BETWEEN 500 AND 1000 THEN 'Medium' 
        ELSE 'High' 
    END AS Spending_Category 
FROM  
    Customers c 
LEFT JOIN  
    Purchases p ON c.CustomerID = p.CustomerID 
LEFT JOIN  
    GeneralCustomers gc ON c.CustomerID = gc.CustomerID 
LEFT JOIN  
    DisabledCustomers dc ON c.CustomerID = dc.CustomerID 
WHERE  
    p.Total_Amount IS NOT NULL 
GROUP BY  
    c.CustomerID, c.Name, gc.Member_Level, dc.Member_Level, gc.CustomerID, dc.CustomerID 
HAVING  
    SUM(p.Total_Amount) IS NOT NULL 
ORDER BY  
    Total_Spent DESC; 

// SQL Query Report #7
// Groups the total number of two factor authentication verifications and lists their success rate percentage 
SELECT 
    t.Method_Type, 
    t.Total_Attempts, 
    NVL(s.Verified_Count, 0) AS Successful_Verifications, 
    NVL((NVL(s.Verified_Count, 0) * 100.0 / t.Total_Attempts), 0) AS Success_Rate_Percentage 
FROM 
    (SELECT 
        Method_Type, 
        COUNT(*) AS Total_Attempts 
     FROM 
        two_factor_Authentication 
     GROUP BY 
        Method_Type) t 
LEFT JOIN 
    (SELECT 
        Method_Type, 
        COUNT(*) AS Verified_Count 
     FROM 
        two_factor_Authentication 
     WHERE 
        Verification_Status = 1 
     GROUP BY 
        Method_Type) s 
ON 
    t.Method_Type = s.Method_Type; 

