-- Verificar que todas las tablas existen (deben salir unas 15 tablas)
SELECT table_name FROM user_tables ORDER BY table_name;

-- Verificar que se han creado las restricciones CHECK que añadimos (números no negativos)
SELECT constraint_name, search_condition 
FROM user_constraints 
WHERE table_name = 'AULA' AND constraint_type = 'C';

-- Verificar que los CSVs se han cargado bien (los números deben ser mayores a 0)
SELECT 'Vocal' AS Tabla, COUNT(*) AS Total FROM VOCAL
UNION ALL
SELECT 'Materia', COUNT(*) FROM MATERIA
UNION ALL
SELECT 'Sede', COUNT(*) FROM SEDE
UNION ALL
SELECT 'Vista Estudiantes', COUNT(*) FROM V_ESTUDIANTES;

-- 1. Ejecutamos el procedimiento para crear 5 aulas por sede, con capacidad 30
EXEC PR_RELLENA_AULAS(5, 30);

-- 2. Comprobamos que se han insertado correctamente en la tabla AULA
SELECT Sede_Codigo, COUNT(*) as Num_Aulas, MAX(Capacidad) as Capacidad
FROM AULA 
GROUP BY Sede_Codigo;

-- 3. Probamos a borrar las aulas de una sede concreta (por ejemplo, la sede con ID '1', cambia el ID si en tu CSV es otro)
EXEC PR_BORRA_AULA_SEDE('1');

-- 4. Borramos todas las aulas para dejar la tabla limpia de nuevo
EXEC PR_BORRA_AULAS;

-- 5. Verificamos que la tabla vuelve a estar vacía
SELECT COUNT(*) FROM AULA;

-- 1. Forzamos un INSERT (aunque dé error por FK, o metiendo datos inventados temporalmente)
-- Como las tablas padre (ESTUDIANTE y EXAMEN) aún no tienen datos definitivos, 
-- la mejor prueba la haremos cuando la BD esté llena. Pero puedes comprobar que el trigger y la tabla existen:
SELECT trigger_name, status FROM user_triggers WHERE trigger_name = 'TR_AUDIT_ASISTENCIA';
SELECT table_name FROM user_tables WHERE table_name = 'LOG_ASISTENCIA';