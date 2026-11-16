-- Hoja de notas de testeo de Vera: tabla y función de guardado.
-- Pegar completo en Supabase > SQL Editor > New query > Run.

create table public.notas_testeo_vera (
  session_id     uuid primary key,
  codigo         text not null check (char_length(codigo) between 1 and 40),
  fecha          date,
  pais           text check (char_length(pais) <= 60),
  facilitadora   text check (char_length(facilitadora) <= 40),
  datos          jsonb not null,
  versiones      integer not null default 1,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

-- RLS activo y sin políticas: con la clave pública nadie puede leer, editar ni borrar la tabla.
alter table public.notas_testeo_vera enable row level security;
revoke all on public.notas_testeo_vera from anon, authenticated;

-- Única puerta de entrada desde la hoja: guardar o actualizar una sesión.
create or replace function public.guardar_sesion_vera(p jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_codigo text := nullif(trim(p->>'codigo'), '');
  v_ver integer;
begin
  if v_codigo is null then raise exception 'Falta el código de la sesión'; end if;
  if p->'datos' is null or jsonb_typeof(p->'datos') <> 'object' then raise exception 'Faltan los datos de la sesión'; end if;
  if pg_column_size(p) > 200000 then raise exception 'La sesión es demasiado grande'; end if;
  v_id := (p->>'session_id')::uuid;

  insert into public.notas_testeo_vera as t (session_id, codigo, fecha, pais, facilitadora, datos)
  values (v_id, v_codigo, nullif(p->>'fecha','')::date, nullif(p->>'pais',''), nullif(p->>'facilitadora',''), p->'datos')
  on conflict (session_id) do update set
    codigo = excluded.codigo, fecha = excluded.fecha, pais = excluded.pais,
    facilitadora = excluded.facilitadora, datos = excluded.datos,
    versiones = t.versiones + 1, actualizado_en = now()
  returning t.versiones into v_ver;

  return jsonb_build_object('ok', true, 'versiones', v_ver);
end;
$$;

revoke all on function public.guardar_sesion_vera(jsonb) from public;
grant execute on function public.guardar_sesion_vera(jsonb) to anon, authenticated;
