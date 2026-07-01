CREATE OR REPLACE FUNCTION get_user_purchased_tickets(p_contact_info VARCHAR)
RETURNS TABLE (
    order_id BIGINT,
    purchase_date TIMESTAMPTZ,
    ticket_id BIGINT,
    ticket_price NUMERIC(10,2),
    seat_section INT,
    seat_row INT,
    seat_number INT,
    match_time TIMESTAMPTZ,
    host_team VARCHAR,
    guest_team VARCHAR,
    venue_name VARCHAR
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ticket_order.order_id,
        ticket_order.created_at AS purchase_date,
        sold_ticket.ticket_id,
        sold_ticket.price AS ticket_price,
        seat.section AS seat_section,
        seat.row_no AS seat_row,
        seat.seat_no AS seat_number,
        matches.match_time,
        host_team.team_name AS host_team,
        guest_team.team_name AS guest_team,
        venue.name AS venue_name
    FROM users
    JOIN ticket_order ON users.user_id = ticket_order.user_id
    JOIN sold_ticket ON ticket_order.order_id = sold_ticket.order_id
    JOIN seat ON sold_ticket.seat_id = seat.seat_id
    JOIN ticket_category_config config ON seat.config_id = config.config_id
    JOIN matches ON config.match_id = matches.match_id
    JOIN team host_team ON matches.host_team_id = host_team.team_id
    JOIN team guest_team ON matches.guest_team_id = guest_team.team_id
    JOIN venue ON matches.venue_id = venue.venue_id
    WHERE (users.email = p_contact_info OR users.phone_number = p_contact_info)
      AND ticket_order.status = 'PAID'
    ORDER BY ticket_order.created_at DESC;
END;
$$;

CREATE OR REPLACE FUNCTION get_users_with_cancelled_reservations(p_support_contact VARCHAR)
RETURNS TABLE (
    customer_id BIGINT,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        customer.user_id AS customer_id,
        customer.first_name AS customer_first_name,
        customer.last_name AS customer_last_name
    FROM users AS support
    JOIN report ON support.user_id = report.support_id
    JOIN reservation res ON report.reservation_id = res.reservation_id
    JOIN users customer ON res.user_id = customer.user_id
    WHERE (
        support.user_id::TEXT = p_support_contact OR
        support.email = p_support_contact OR
        support.phone_number = p_support_contact
    ) AND res.status = 'CANCELLED';
END;
$$;

CREATE OR REPLACE FUNCTION get_sold_tickets_by_city(p_city_input VARCHAR)
RETURNS TABLE (
    ticket_id BIGINT,
    order_id BIGINT,
    ticket_price NUMERIC(10,2),
    seat_section INT,
    seat_row INT,
    seat_number INT,
    match_time TIMESTAMPTZ,
    host_team VARCHAR,
    guest_team VARCHAR,
    venue_name VARCHAR,
    city_name VARCHAR
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sold_ticket.ticket_id,
        sold_ticket.order_id,
        sold_ticket.price AS ticket_price,
        seat.section AS seat_section,
        seat.row_no AS seat_row,
        seat.seat_no AS seat_number,
        matches.match_time,
        host_team.team_name AS host_team,
        guest_team.team_name AS guest_team,
        venue.name AS venue_name,
        city.name AS city_name
    FROM sold_ticket
    JOIN seat ON sold_ticket.seat_id = seat.seat_id
    JOIN ticket_category_config config ON seat.config_id = config.config_id
    JOIN matches ON config.match_id = matches.match_id
    JOIN team host_team ON matches.host_team_id = host_team.team_id
    JOIN team guest_team ON matches.guest_team_id = guest_team.team_id
    JOIN venue ON matches.venue_id = venue.venue_id
    JOIN city ON venue.city_id = city.city_id
    WHERE city.name = p_city_input 
       OR city.city_id::TEXT = p_city_input
    ORDER BY matches.match_time DESC, sold_ticket.ticket_id;
END;
$$;

CREATE OR REPLACE FUNCTION search_tickets_by_keyword(p_search VARCHAR)
RETURNS TABLE (
    ticket_id BIGINT,
    spectator_first_name VARCHAR,
    spectator_last_name VARCHAR,
    host_team VARCHAR,
    guest_team VARCHAR,
    venue_name VARCHAR,
    category_name VARCHAR,
    match_time TIMESTAMPTZ
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sold_ticket.ticket_id,
        users.first_name AS spectator_first_name,
        users.last_name AS spectator_last_name,
        host_team.team_name AS host_team,
        guest_team.team_name AS guest_team,
        venue.name AS venue_name,
        ticket_category.name AS category_name,
        matches.match_time
    FROM sold_ticket
    JOIN ticket_order ON sold_ticket.order_id = ticket_order.order_id
    JOIN users ON ticket_order.user_id = users.user_id
    JOIN seat ON sold_ticket.seat_id = seat.seat_id
    JOIN ticket_category_config config ON seat.config_id = config.config_id
    JOIN ticket_category ON config.category_id = ticket_category.category_id
    JOIN matches ON config.match_id = matches.match_id
    JOIN team host_team ON matches.host_team_id = host_team.team_id
    JOIN team guest_team ON matches.guest_team_id = guest_team.team_id
    JOIN venue ON matches.venue_id = venue.venue_id
    WHERE users.first_name ILIKE '%' || p_search || '%'
       OR users.last_name ILIKE '%' || p_search || '%'
       OR host_team.team_name ILIKE '%' || p_search || '%'
       OR guest_team.team_name ILIKE '%' || p_search || '%'
       OR venue.name ILIKE '%' || p_search || '%'
       OR ticket_category.name ILIKE '%' || p_search || '%';
END;
$$;

CREATE OR REPLACE FUNCTION get_users_in_same_city(p_contact_info VARCHAR)
RETURNS SETOF users
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT other_user.*
    FROM users AS target_user
    JOIN users AS other_user ON target_user.city_id = other_user.city_id
    WHERE (target_user.email = p_contact_info OR target_user.phone_number = p_contact_info)
      AND other_user.user_id <> target_user.user_id;
END;
$$;

CREATE OR REPLACE FUNCTION get_top_ticket_buyers(p_start_date TIMESTAMPTZ, p_limit_count INT)
RETURNS TABLE (
    user_id BIGINT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone_number VARCHAR,
    total_tickets BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        users.user_id,
        users.first_name,
        users.last_name,
        users.email,
        users.phone_number,
        COUNT(sold_ticket.ticket_id) AS total_tickets
    FROM users
    JOIN ticket_order ON users.user_id = ticket_order.user_id
    JOIN sold_ticket ON ticket_order.order_id = sold_ticket.order_id
    WHERE ticket_order.created_at >= p_start_date
      AND ticket_order.status = 'PAID'
    GROUP BY 
        users.user_id, 
        users.first_name, 
        users.last_name, 
        users.email, 
        users.phone_number
    ORDER BY total_tickets DESC
    LIMIT p_limit_count;
END;
$$;

CREATE OR REPLACE FUNCTION get_cancelled_tickets_by_sport(p_sport_name VARCHAR)
RETURNS TABLE (
    reservation_id BIGINT,
    reservation_date TIMESTAMPTZ,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    match_time TIMESTAMPTZ,
    host_team VARCHAR,
    guest_team VARCHAR,
    venue_name VARCHAR,
    seat_section INT,
    seat_row INT,
    seat_number INT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        reservation.reservation_id,
        reservation.created_at AS reservation_date,
        users.first_name AS customer_first_name,
        users.last_name AS customer_last_name,
        matches.match_time,
        host_team.team_name AS host_team,
        guest_team.team_name AS guest_team,
        venue.name AS venue_name,
        seat.section AS seat_section,
        seat.row_no AS seat_row,
        seat.seat_no AS seat_number
    FROM reservation
    JOIN users ON reservation.user_id = users.user_id
    JOIN reservation_seat ON reservation.reservation_id = reservation_seat.reservation_id
    JOIN seat ON reservation_seat.seat_id = seat.seat_id
    JOIN ticket_category_config config ON seat.config_id = config.config_id
    JOIN matches ON config.match_id = matches.match_id
    JOIN sport ON matches.sport_id = sport.sport_id
    JOIN team host_team ON matches.host_team_id = host_team.team_id
    JOIN team guest_team ON matches.guest_team_id = guest_team.team_id
    JOIN venue ON matches.venue_id = venue.venue_id
    WHERE sport.sport_name = p_sport_name
      AND reservation.status = 'CANCELLED'
    ORDER BY matches.match_time DESC;
END;
$$;

CREATE OR REPLACE FUNCTION get_top_reporters_by_type(p_report_topic VARCHAR, p_limit_count INT DEFAULT 10)
RETURNS TABLE (
    user_id BIGINT,
    first_name VARCHAR,
    last_name VARCHAR,
    email VARCHAR,
    phone_number VARCHAR,
    total_reports BIGINT
) 
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        users.user_id,
        users.first_name,
        users.last_name,
        users.email,
        users.phone_number,
        COUNT(report.report_id) AS total_reports
    FROM users
    JOIN report ON users.user_id = report.user_id
    WHERE report.type = p_report_topic::report_type
    GROUP BY 
        users.user_id,
        users.first_name,
        users.last_name,
        users.email,
        users.phone_number
    ORDER BY total_reports DESC
    LIMIT p_limit_count;
END;
$$;