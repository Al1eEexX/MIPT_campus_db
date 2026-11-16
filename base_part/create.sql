drop schema if exists campus cascade;
create schema campus;

create table campus.groups (
	group_number varchar(10) primary key,
	course_number smallint not null check (course_number between 1 and 4),
	phystech_school varchar(10) not null,
	constraint group_number_format check (group_number ~ '^[БМА](0[1-9]|1[0-5])-([0-9]{3})$')
);

create table campus.students (
	student_id serial primary key,
	full_name varchar(50) not null,
	email varchar(50) unique not null,
	phone_number varchar(20) unique not null,
	group_number varchar(10) not null references campus.groups(group_number) on delete restrict,
	constraint student_email_format check(email ~ '^[a-z_.0-9]+@phystech.edu$'),
	constraint student_phone_number_format check(phone_number ~ '^\+[78] \([0-9]{3}\) [0-9]{3}-[0-9]{2}-[0-9]{2}$')
);

create table campus.relatives (
	relative_id smallint primary key,
	full_name varchar(50) not null,
	phone_number varchar(20) unique not null,
	email varchar(50) unique not null,
	constraint relative_phone_number_format check(phone_number ~ '^\+[78] \([0-9]{3}\) [0-9]{3}-[0-9]{2}-[0-9]{2}$'),
	constraint relative_email_format check(email ~ '^[a-z0-9._]+@[a-z]+\.[a-z]{2,}')
);

create table campus.family (
	student_id smallint references campus.students(student_id) on delete cascade,
	relative_id smallint references campus.relatives(relative_id) on delete cascade,
	kinship_degree varchar(20) not null,
	primary key(student_id, relative_id)
);

create table campus.dormitory (
	dormitory_id smallint primary key,
	address varchar(100) unique not null,
	name varchar(30) unique not null,
	type varchar(10),
	capacity smallint not null check (capacity > 0),
	constraint dormitory_type check(type IN ('Коридорное', 'Квартирное'))
);

create table campus.room_info (
	room_number smallint,
	dormitory_id smallint references campus.dormitory(dormitory_id) on delete restrict,
	status varchar(15),
	capacity smallint not null check (capacity between 3 and 6),
	primary key (room_number, dormitory_id),
	constraint status_types check (status in ('Заселена', 'Нежилая', 'На ремонте'))
);

create table campus.accommodation (
	student_id smallint primary key references campus.students(student_id) on delete cascade,
	dormitory_id smallint not null references campus.dormitory(dormitory_id) on delete restrict,
	room_number smallint not null,
	foreign key (dormitory_id, room_number) references campus.room_info(dormitory_id, room_number) on delete restrict
);

create table campus.violations (
	student_id smallint references campus.students(student_id) on delete cascade,
	date date,
	violation_type text not null,
	fine varchar(10) check (fine IN ('Замечание', 'Выговор', 'Исключение')),
	comment text not null default('Без дополнительных комментариев'),
	primary key(student_id, date)
);

create table campus.entry_exit_time (
	student_id smallint references campus.students(student_id) on delete cascade,
	last_entry_time timestamp,
	last_exit_time timestamp,
	dormitory_id smallint not null references campus.dormitory(dormitory_id) on delete restrict,
	primary key(student_id, last_entry_time),
	constraint exit_time_format check(last_exit_time is null or last_exit_time > last_entry_time)
);

create table if not exists campus.staff_info (
	staff_id smallint primary key,
	full_name varchar(50) not null,
	phone_number varchar(20) unique not null,
	email varchar(50) unique not null,
	post varchar(20) not null,
	constraint staff_phone_number_format check(phone_number ~ '^\+[78] \([0-9]{3}\) [0-9]{3}-[0-9]{2}-[0-9]{2}$'),
	constraint staff_email_format check(email ~ '^[a-z_.0-9]+@phystech.edu$')
);

create table campus.dormitory_staff (
	staff_id smallint references campus.staff_info(staff_id) on delete cascade,
	dormitory_id smallint references campus.dormitory(dormitory_id) on delete restrict,
	primary key(staff_id, dormitory_id)
);

create table campus.history_of_living (
	student_id smallint references campus.students(student_id) on delete cascade,
	date_of_move date,
	dormitory_moved_to smallint,
	dormitory_moved_from smallint,
	room_moved_to smallint,
	room_moved_from smallint,
	primary key (student_id, date_of_move),
	foreign key (dormitory_moved_from, room_moved_from) references campus.room_info (dormitory_id, room_number) on delete restrict,
	foreign key (dormitory_moved_to, room_moved_to) references campus.room_info (dormitory_id, room_number) on delete restrict
);
