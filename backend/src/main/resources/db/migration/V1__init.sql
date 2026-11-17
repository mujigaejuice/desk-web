create table member (
    id         bigint generated always as identity primary key,
    name       varchar(50)  not null,
    login_id   varchar(50)  not null unique,
    password   varchar(100) not null,
    role       varchar(20)  not null,
    extension  varchar(20),
    created_at timestamptz  not null default now()
);
