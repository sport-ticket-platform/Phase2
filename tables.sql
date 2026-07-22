CREATE TABLE city (
    city_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL
);

CREATE TABLE sport (
    sport_id SERIAL PRIMARY KEY,
    sport_name varchar(50) NOT NULL
);

CREATE TYPE user_role AS ENUM (
    'USER',
    'ADMIN',
    'SUPPORT'
);

CREATE TABLE users (
    user_id BIGSERIAL PRIMARY KEY,
    first_name varchar(50) NOT NULL,
    last_name varchar(50) NOT NULL,
    role user_role NOT NULL DEFAULT 'USER',
    email varchar(255) NOT NULL UNIQUE,
    email_verified bool DEFAULT false NOT NULL,
    phone_number varchar(20) NOT NULL UNIQUE,
    phone_verified bool DEFAULT false NOT NULL,
    registration_date timestamptz DEFAULT CURRENT_TIMESTAMP NOT NULL,
    password varchar(255) NOT NULL,
    balance numeric(12, 2) DEFAULT 0 NOT NULL,
    city_id INT NOT NULL REFERENCES city(city_id),
    status bool DEFAULT true NOT NULL,
    two_factor_enabled bool DEFAULT false NOT NULL
);

CREATE TABLE team (
    team_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,
    sport_id INT NOT NULL REFERENCES sport(sport_id),
    city_id INT NOT NULL REFERENCES city(city_id)
);

CREATE TABLE venue (
    venue_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,
    city_id INT NOT NULL REFERENCES city(city_id),
    street varchar(255) NOT NULL,
    postal_code varchar(15) NOT NULL,
    latitude decimal Not Null,
    longitude decimal Not Null
);

CREATE TABLE league (
    league_id SERIAL PRIMARY KEY,
    name varchar(50) NOT NULL,
    sport_id int4 NOT NULL REFERENCES sport(sport_id),
    UNIQUE (sport_id, name)
);

CREATE TABLE "match" (
    match_id BIGSERIAL PRIMARY KEY,
    league_id INT NOT NULL REFERENCES league(league_id),
    sport_id INT NOT NULL REFERENCES sport(sport_id),
    venue_id INT NOT NULL REFERENCES venue(venue_id),
    match_time timestamptz NOT NULL,
    host_team_id INT NOT NULL REFERENCES team(team_id),
    guest_team_id INT NOT NULL REFERENCES team(team_id),
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

CREATE TABLE refresh_token (
    token_id BIGSERIAL PRIMARY KEY,
    token varchar(255) NOT NULL UNIQUE,
    user_id BIGINT NOT NULL REFERENCES users(user_id),
    created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expiration_date timestamptz NOT NULL,
    is_active bool NOT NULL DEFAULT true,
    revoked_at timestamptz,
    revoked_reason text,
    ip_address varchar(45),
    user_agent text,
    device_id varchar(255)
);
CREATE INDEX idx_refresh_token_user_id
ON refresh_token(user_id);

CREATE INDEX idx_refresh_token_is_active
ON refresh_token(is_active);

CREATE INDEX idx_refresh_token_device_id
ON refresh_token(device_id);

CREATE TABLE app_setting (
    id BIGINT PRIMARY KEY DEFAULT 1,
    max_failed_login_attempts INT NOT NULL
        CHECK (max_failed_login_attempts >= 1)
        DEFAULT 5,

    account_lockout_duration_second INT NOT NULL
        CHECK (account_lockout_duration_second >= 60)
        DEFAULT 600,

    allow_concurrent_logins BOOLEAN NOT NULL DEFAULT true,
    maintenance_mode BOOLEAN NOT NULL DEFAULT false,
    allow_new_registrations BOOLEAN NOT NULL DEFAULT true,
    allow_login BOOLEAN NOT NULL DEFAULT true,
    CHECK (id = 1)
);
