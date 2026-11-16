-- 1) Автоматическое освобождение комнаты при выселении последнего жильца

drop trigger if exists trg_room_status_accommodation_delete on campus.accommodation;
drop function if exists campus.trigger_update_room_status_after_delete;

create function campus.trigger_update_room_status_after_delete()
returns trigger
language plpgsql
as $$
declare
	rec record;
	room_counter int = 0;
begin
	for rec in select room_number, dormitory_id from campus.room_info ri where not exists 
		(select 1 from campus.accommodation a where a.dormitory_id = ri.dormitory_id and a.room_number = ri.room_number)
		and (ri.status = 'Заселена') loop
		update campus.room_info
			set status = 'Нежилая'
			where room_number = rec.room_number and dormitory_id = rec.dormitory_id;
		raise notice 'Комната % в общежитии % переведена в статус ''Нежилая''', rec.room_number, rec.dormitory_id;
		room_counter = room_counter + 1;
	end loop;

	if room_counter > 0 then
		raise notice 'Комнат переведено в статус ''Нежилая'': % шт.', room_counter;
	end if;

	return null;
end;
$$;

create trigger trg_room_status_accommodation_delete
after delete on campus.accommodation
for each statement
execute function campus.trigger_update_room_status_after_delete();

-- 2) Автоматическое изменение статуса комнаты на 'Заселена' при заселении в нее
-- первого студента

drop trigger if exists trg_room_status_insertion on campus.accommodation;
drop function if exists campus.trigger_update_room_status_after_insertion;

create function campus.trigger_update_room_status_after_insertion()
returns trigger
language plpgsql
as $$
begin
	update campus.room_info ri
	set status = 'Заселена'
	where ri.dormitory_id = new.dormitory_id and ri.room_number = new.room_number
		and status != 'Заселена';
	raise notice 'Комната % в общежитии % теперь заселена.', new.room_number, new.dormitory_id;
	return new;
end;
$$;

create trigger trg_room_status_insertion
after insert on campus.accommodation
for each row
execute function campus.trigger_update_room_status_after_insertion();
