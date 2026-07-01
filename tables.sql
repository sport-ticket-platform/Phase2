CREATE TABLE city (
    city_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL
);

CREATE TABLE sport (
    sport_id SERIAL PRIMARY KEY,
    sport_name varchar(50) NOT NULL
);

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    role varchar(50) NOT NULL,
    email varchar(255) NOT NULL UNIQUE,
    email_verified bool DEFAULT false NOT NULL,
    phone_number varchar(20) NOT NULL UNIQUE,
    phone_verified bool DEFAULT false NOT NULL,
    registration_date timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    password varchar(255) NOT NULL,
    balance numeric(12, 2) DEFAULT 0 NOT NULL,
    city_id INT NOT NULL REFERENCES city(city_id),
    status bool DEFAULT true NOT NULL
);

CREATE TABLE team (
    team_id SERIAL PRIMARY KEY,
    team_name varchar(50) NOT NULL,
    sport_id INT NOT NULL REFERENCES sport(sport_id),
    city_id INT NOT NULL REFERENCES city(city_id)
);

CREATE TABLE venue (
    venue_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,
    city_id INT NOT NULL REFERENCES city(city_id),
    full_address varchar(255) NOT NULL
);

CREATE TABLE organizer (
    organizer_id SERIAL PRIMARY KEY,
    is_company bool DEFAULT true NOT NULL,
    name varchar(50) NOT NULL,
    email varchar(255) NOT NULL UNIQUE,
    phone_number varchar(20) NOT NULL UNIQUE
);

CREATE TABLE league (
    league_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,
    sport_id int4 NOT NULL REFERENCES sport(sport_id),
    UNIQUE (sport_id, name)
);

CREATE TABLE matches (
    match_id BIGSERIAL PRIMARY KEY,
    league_id INT NOT NULL REFERENCES league(league_id),
    sport_id INT NOT NULL REFERENCES sport(sport_id),
    venue_id INT NOT NULL REFERENCES venue(venue_id),
    match_time timestamptz NOT NULL,
    host_team_id INT NOT NULL REFERENCES team(team_id),
    guest_team_id INT NOT NULL REFERENCES team(team_id),
    organizer_id INT NOT NULL REFERENCES organizer(organizer_id),
    CHECK(host_team_id <> guest_team_id)
);

CREATE TABLE ticket_category (
    category_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL
);

CREATE TABLE ticket_category_config (
  config_id SERIAL PRIMARY KEY,
  match_id bigint NOT NULL REFERENCES matches(match_id),
  category_id INT NOT NULL REFERENCES ticket_category(category_id),
  price numeric(10, 2) NOT NULL CHECK(price >= 0),
  amenities JSONB,
  total_seats int4 NOT NULL,
  UNIQUE(match_id, category_id)
);

CREATE TABLE seat (
    seat_id BIGSERIAL PRIMARY KEY,
    config_id INT NOT NULL REFERENCES ticket_category_config(config_id),
    section INT NOT NULL,
    row_no INT NOT NULL,
    seat_no INT NOT NULL,
    UNIQUE(config_id, section, row_no, seat_no)
);

CREATE TYPE reservation_status AS ENUM (
    'ACTIVE',
    'EXPIRED',
    'COMPLETED',
    'CANCELLED'
);

CREATE TABLE reservation (
    reservation_id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    status reservation_status NOT NULL DEFAULT 'ACTIVE'
);

CREATE TABLE reservation_seat (
    reservation_id BIGINT NOT NULL REFERENCES reservation(reservation_id),
    seat_id BIGINT NOT NULL REFERENCES seat(seat_id),
    is_active BOOLEAN NOT NULL DEFAULT true,
    PRIMARY KEY (reservation_id, seat_id)
);

CREATE UNIQUE INDEX uq_seat_active_once
    ON reservation_seat (seat_id)
    WHERE is_active;

CREATE TYPE order_status AS ENUM (
    'PENDING',
    'PAID',
    'FAILED',
    'REFUNDED'
);

CREATE TABLE ticket_order (
    order_id BIGSERIAL PRIMARY KEY,
    reservation_id BIGINT UNIQUE REFERENCES reservation(reservation_id),
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    status order_status NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payment_methods (
    method_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,        
    fee_percentage numeric(5,2),
    is_active boolean DEFAULT true
);

CREATE TYPE payment_status AS ENUM (
    'PENDING',
    'SUCCEEDED',
    'FAILED',
    'REFUNDED'
);

CREATE TABLE payment (
    payment_id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES ticket_order(order_id),
    method_id INT NOT NULL REFERENCES payment_methods(method_id),
    amount NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
    paid_at TIMESTAMPTZ,
    status payment_status NOT NULL DEFAULT 'PENDING'
);

CREATE TABLE sold_ticket (
    ticket_id BIGSERIAL PRIMARY KEY,
    seat_id BIGINT NOT NULL REFERENCES seat(seat_id),
    order_id BIGINT NOT NULL REFERENCES ticket_order(order_id),
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    UNIQUE(seat_id)
);

CREATE TYPE report_type AS ENUM (
    'PAYMENT_ISSUE',
    'RESERVATION_ISSUE',
    'CANCEL_RESERVATION',
    'TECHNICAL_BUG',
    'COMPLAINT',
    'OTHER'
);

CREATE TYPE report_status AS ENUM (
    'OPEN',
    'IN_PROGRESS',
    'RESOLVED',
    'CLOSED'
);

CREATE TABLE report (
    report_id SERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    support_id INT REFERENCES users(user_id),
    reservation_id BIGINT REFERENCES reservation(reservation_id),
    payment_id BIGINT REFERENCES payment(payment_id),
    type report_type NOT NULL,
    reported_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    report text NOT NULL,
    status report_status NOT NULL,
    response text,
    responded_at timestamptz
);