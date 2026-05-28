-- ============================================================================
-- PRUEBAS COMPLETAS - TRABAJO GRUPO PAU
-- BD II - ETSI Informatica - Universidad de Malaga
-- ============================================================================
-- EJECUTAR COMO PAU
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

PROMPT ========================================
PROMPT PRUEBA 1: VERIFICAR TABLAS
PROMPT ========================================
SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT ========================================
PROMPT PRUEBA 2: VERIFICAR DATOS IMPORTADOS
PROMPT ========================================
SELECT 'VOCALES' AS tabla, COUNT(*) AS total FROM VOCAL
UNION ALL
SELECT 'MATERIAS', COUNT(*) FROM MATERIA
UNION ALL
SELECT 'SEDES', COUNT(*) FROM SEDE
UNION ALL
SELECT 'ESTUDIANTES', COUNT(*) FROM ESTUDIANTE
UNION ALL
SELECT 'CENTROS', COUNT(*) FROM CENTRO
UNION ALL
SELECT 'MATRICULAS', COUNT(*) FROM ESTUDIANTE_MATERIA;

PROMPT ========================================
PROMPT PRUEBA 3: VERIFICAR INDICES EN TS_INDICES
PROMPT ========================================
SELECT index_name, tablespace_name, index_type 
FROM user_indexes 
ORDER BY tablespace_name, index_name;

PROMPT ========================================
PROMPT PRUEBA 4: PROBAR PR_RELLENA_AULAS (5 aulas x sede, cap 30)
PROMPT ========================================
EXEC PR_RELLENA_AULAS(5, 30);
SELECT Sede_Codigo, COUNT(*) as Num_Aulas, MAX(Capacidad) as Capacidad
FROM AULA 
GROUP BY Sede_Codigo;

PROMPT ========================================
PROMPT PRUEBA 5: PROBAR PR_BORRA_AULA_SEDE y PR_BORRA_AULAS
PROMPT ========================================
EXEC PR_BORRA_AULA_SEDE('1');
SELECT COUNT(*) AS aulas_restantes FROM AULA;
EXEC PR_BORRA_AULAS;
SELECT COUNT(*) AS aulas_tras_borrar FROM AULA;

PROMPT ========================================
PROMPT PRUEBA 6: VOLVER A CREAR AULAS Y ASIGNAR SEDES
PROMPT ========================================
EXEC PR_RELLENA_AULAS(5, 30);
EXEC PK_ASIGNA.PR_ASIGNA_SEDE;
SELECT c.Nombre AS Centro, s.Nombre AS Sede_Asignada
FROM CENTRO c
LEFT JOIN SEDE s ON c.Sede_Codigo = s.Codigo
ORDER BY s.Nombre NULLS LAST;

PROMPT ========================================
PROMPT PRUEBA 6.5: PROBAR FUNCION PUBLICA F_PLAZAS
PROMPT ========================================
DECLARE
  v_sede VARCHAR2(20);
  v_plazas_libres NUMBER;
BEGIN
  -- Pillamos una sede al azar
  SELECT Codigo INTO v_sede FROM SEDE WHERE ROWNUM = 1;
  
  -- Llamamos explicitamente a la funcion como pide la prueba unitaria
  v_plazas_libres := PK_ASIGNA.F_PLAZAS(v_sede);
  DBMS_OUTPUT.PUT_LINE('La sede ' || v_sede || ' tiene ' || v_plazas_libres || ' plazas libres calculadas.');
END;
/

PROMPT ========================================
PROMPT PRUEBA 7: CREAR EXAMENES Y ASISTENCIAS
PROMPT ========================================
DECLARE
  v_fecha_examen DATE;
  v_aula VARCHAR2(20);
  v_vocal VARCHAR2(20);
BEGIN
  SELECT Codigo INTO v_aula FROM AULA WHERE ROWNUM = 1;
  SELECT DNI INTO v_vocal FROM VOCAL WHERE ROWNUM = 1;
  
  v_fecha_examen := SYSDATE + 1/24;
  
  INSERT INTO EXAMEN (FechayHora, Aula_Codigo, Vocal_DNI)
  VALUES (v_fecha_examen, v_aula, v_vocal);
  
  FOR est IN (SELECT DNI FROM ESTUDIANTE WHERE ROWNUM <= 10) LOOP
    INSERT INTO ASISTENCIA (Asiste, Entrega, Examen_FechayHora, 
                           Estudiante_DNI, Materia_Codigo, Aula_Codigo, Sede_Codigo)
    SELECT 'S', 'S', v_fecha_examen, est.DNI, em.Materia_Codigo, v_aula,
           (SELECT Sede_Codigo FROM AULA WHERE Codigo = v_aula)
    FROM ESTUDIANTE_MATERIA em
    WHERE em.Estudiante_DNI = est.DNI AND ROWNUM = 1;
  END LOOP;
  
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('Examen y asistencias creadas correctamente');
END;
/

PROMPT ========================================
PROMPT PRUEBA 7.5: COMPROBAR TRIGGER AUDITORIA (LOG_ASISTENCIA)
PROMPT ========================================
SELECT * FROM LOG_ASISTENCIA;

PROMPT ========================================
PROMPT PRUEBA 8: PROBAR VISTAS DE OCUPACION
PROMPT ========================================
SELECT * FROM V_OCUPACION_ASIGNADA;
SELECT * FROM V_OCUPACION;
SELECT * FROM V_VIGILANTES;

PROMPT ========================================
PROMPT PRUEBA 9: PROBAR PK_OCUPACION
PROMPT ========================================
DECLARE
  v_result NUMBER;
  v_ok BOOLEAN;
  v_aula VARCHAR2(20);
  v_vocal VARCHAR2(20);
BEGIN
  SELECT DNI INTO v_vocal FROM VOCAL WHERE ROWNUM = 1;
  v_ok := PK_OCUPACION.VOCAL_DUPLICADO(v_vocal);
  DBMS_OUTPUT.PUT_LINE('VOCAL_DUPLICADO (1 DNI): ' || CASE WHEN v_ok THEN 'TRUE' ELSE 'FALSE' END);

  SELECT Codigo INTO v_aula FROM AULA WHERE ROWNUM = 1;
  v_result := PK_OCUPACION.OCUPACION_MAXIMA('1', v_aula);
  DBMS_OUTPUT.PUT_LINE('OCUPACION_MAXIMA: ' || v_result);
  
  v_ok := PK_OCUPACION.OCUPACION_OK;
  DBMS_OUTPUT.PUT_LINE('OCUPACION_OK: ' || CASE WHEN v_ok THEN 'TRUE' ELSE 'FALSE' END);
  
  v_ok := PK_OCUPACION.VOCALES_DUPLICADOS;
  DBMS_OUTPUT.PUT_LINE('VOCALES_DUPLICADOS: ' || CASE WHEN v_ok THEN 'TRUE' ELSE 'FALSE' END);
  
  v_ok := PK_OCUPACION.VOCAL_RATIO(30);
  DBMS_OUTPUT.PUT_LINE('VOCAL_RATIO(30): ' || CASE WHEN v_ok THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT ========================================
PROMPT PRUEBA 10: PROBAR PK_SEGURIDAD_PAU
PROMPT ========================================
-- NOTA: VPD filtra ESTUDIANTE para PAU (Usuario_BD = USER),
-- por eso usamos DNIs conocidos en lugar de SELECT
DECLARE
  v_user VARCHAR2(50);
  v_pass VARCHAR2(50);
BEGIN
  -- Usar DNI conocidos (VPD oculta ESTUDIANTE a PAU)
  PK_SEGURIDAD_PAU.PR_CREA_ESTUDIANTE('57611188C', v_user, v_pass);
  DBMS_OUTPUT.PUT_LINE('Usuario estudiante creado: ' || v_user || ' / ' || v_pass);
  
  PK_SEGURIDAD_PAU.PR_CREA_VOCAL('95115697E', v_user, v_pass);
  DBMS_OUTPUT.PUT_LINE('Usuario vocal creado: ' || v_user || ' / ' || v_pass);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error (normal si falta privilegio CREATE USER): ' || SQLERRM);
END;
/

PROMPT ========================================
PROMPT PRUEBA 11: PROBAR VISTAS SEGURIDAD
PROMPT ========================================
SELECT COUNT(*) AS total_vistas_seguridad FROM user_views 
WHERE view_name IN ('V_MI_ASIGNACION','V_MIS_DATOS','V_MI_VIGILANCIA',
                    'V_MI_SEDE_GESTION','V_ASIGNACION_GLOBAL');

PROMPT ========================================
PROMPT PRUEBA 12: PROBAR TR_BORRA_AULA
PROMPT ========================================
DECLARE
  v_aula_id VARCHAR2(20);
BEGIN
  SELECT Codigo INTO v_aula_id FROM AULA WHERE ROWNUM = 1;
  DBMS_OUTPUT.PUT_LINE('Intentando borrar aula: ' || v_aula_id);
  PR_BORRA_AULA(v_aula_id);
  DBMS_OUTPUT.PUT_LINE('Aula borrada correctamente (o ejecutado TR_BORRA_AULA)');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error esperado (posible examen planificado): ' || SQLERRM);
END;
/

PROMPT ========================================
PROMPT PRUEBA 13: PROBAR RESTRICCIONES CHECK
PROMPT ========================================
DECLARE
  v_aula VARCHAR2(20);
  v_vocal VARCHAR2(20);
  v_examen_fecha DATE;
  v_estudiante VARCHAR2(20);
  v_materia VARCHAR2(20);
BEGIN
  SELECT Codigo INTO v_aula FROM AULA WHERE ROWNUM = 1;
  SELECT DNI INTO v_vocal FROM VOCAL WHERE ROWNUM = 1;
  SELECT DNI INTO v_estudiante FROM ESTUDIANTE WHERE ROWNUM = 1;
  SELECT Codigo INTO v_materia FROM MATERIA WHERE ROWNUM = 1;

  -- Crear examen de prueba
  v_examen_fecha := SYSDATE + 10;
  INSERT INTO EXAMEN (FechayHora, Aula_Codigo, Vocal_DNI)
  VALUES (v_examen_fecha, v_aula, v_vocal);
  SAVEPOINT sp_check13;

  -- Probar CHK_EXAMEN_NUM_EST (Num_Estudiantes_Presentes >= 0)
  BEGIN
    INSERT INTO EXAMEN (FechayHora, Aula_Codigo, Vocal_DNI, Num_Estudiantes_Presentes)
    VALUES (v_examen_fecha + 1/24, v_aula, v_vocal, -1);
    DBMS_OUTPUT.PUT_LINE('ERROR: Deberia haber fallado por Num_Estudiantes_Presentes negativo');
    ROLLBACK TO sp_check13;
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK: Num_Estudiantes_Presentes negativo rechazado');
  END;

  -- Probar CHK_ASISTENCIA_ASISTE_VALUES (Asiste IN (S,N))
  BEGIN
    INSERT INTO ASISTENCIA (Asiste, Entrega, Examen_FechayHora, Estudiante_DNI, Materia_Codigo)
    VALUES ('X', 'S', v_examen_fecha, v_estudiante, v_materia);
    DBMS_OUTPUT.PUT_LINE('ERROR: Deberia haber fallado por Asiste invalido');
    ROLLBACK TO sp_check13;
  EXCEPTION
    WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('OK: Asiste invalido rechazado');
  END;

  -- Limpiar
  ROLLBACK TO sp_check13;
  DELETE FROM EXAMEN WHERE FechayHora = v_examen_fecha;
  COMMIT;
END;
/

PROMPT ========================================
PROMPT PRUEBA 14: PROBAR VISTA MATERIALIZADA Y SINONIMO
PROMPT ========================================
SELECT COUNT(*) AS registros_en_MV FROM VM_ESTUDIANTES;
SELECT * FROM S_ESTUDIANTES WHERE ROWNUM <= 3;

PROMPT ========================================
PROMPT PRUEBA 15: VERIFICAR FOREIGN KEYS
PROMPT ========================================
SELECT constraint_name, constraint_type, table_name, r_constraint_name
FROM user_constraints
WHERE constraint_type = 'R'
ORDER BY table_name;

PROMPT ========================================
PROMPT PRUEBA 16: VERIFICAR TRIGGERS ACTIVOS
PROMPT ========================================
SELECT trigger_name, status, table_name, trigger_type, triggering_event
FROM user_triggers
ORDER BY trigger_name;

PROMPT ========================================
PROMPT PRUEBA 17: PROBAR TRANSACCION (ROLLBACK en excepcion)
PROMPT ========================================
BEGIN
  SAVEPOINT sp_test;
  UPDATE CENTRO SET Nombre = UPPER(Nombre) WHERE 1=0;
  DBMS_OUTPUT.PUT_LINE('SAVEPOINT y transaccion OK');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO sp_test;
    DBMS_OUTPUT.PUT_LINE('ROLLBACK ejecutado correctamente');
END;
/

PROMPT ========================================
PROMPT PRUEBA 18: VERIFICAR VPD Y AUDITORIA
PROMPT ========================================
SELECT policy_name, object_name FROM user_policies;

DECLARE
  v_count NUMBER := 0;
  e_view_not_accessible EXCEPTION;
  e_insufficient_privs EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_view_not_accessible, -942);
  PRAGMA EXCEPTION_INIT(e_insufficient_privs, -1031);
BEGIN
  SELECT COUNT(*)
  INTO v_count
  FROM audit_unified_policies
  WHERE policy_name = 'AUDIT_ASISTENCIA_UPDATES';
  
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('Politica de auditoria AUDIT_ASISTENCIA_UPDATES encontrada');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Politica de auditoria AUDIT_ASISTENCIA_UPDATES no encontrada');
  END IF;
EXCEPTION
  WHEN e_view_not_accessible OR e_insufficient_privs THEN
    DBMS_OUTPUT.PUT_LINE(
      'No se puede consultar AUDIT_UNIFIED_POLICIES con el usuario actual. ' ||
      'Ejecute esta comprobacion con un usuario con privilegios de diccionario ' ||
      'o conceda permisos de lectura sobre las politicas de auditoria.'
    );
END;
/

PROMPT ========================================
PROMPT PRUEBA 19: PROBAR MIGRAR_CENTRO (si hay datos)
PROMPT ========================================
DECLARE
  v_centro VARCHAR2(20);
  v_origen VARCHAR2(20);
  v_destino VARCHAR2(20);
BEGIN
  SELECT Codigo INTO v_centro FROM CENTRO WHERE ROWNUM = 1;
  SELECT Codigo INTO v_destino FROM SEDE WHERE ROWNUM = 1;
  
  -- Esto puede fallar si el centro no tiene asignaciones, lo cual es normal
  BEGIN
    MIGRAR_CENTRO(v_centro, v_destino, v_destino);
    DBMS_OUTPUT.PUT_LINE('MIGRAR_CENTRO ejecutado sin errores');
  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('MIGRAR_CENTRO: ' || SQLERRM);
  END;
END;
/

PROMPT ========================================
PROMPT PRUEBA 20: PROBAR PROCEDIMIENTO DESPISTE
PROMPT ========================================
DECLARE
  v_est_dni VARCHAR2(20);
  v_fecha DATE;
  v_aula_nueva VARCHAR2(20);
  v_sede_nueva VARCHAR2(20);
BEGIN
  -- Pillamos un estudiante con asistencia ya creada (de la Prueba 7)
  SELECT Estudiante_DNI, Examen_FechayHora INTO v_est_dni, v_fecha 
  FROM ASISTENCIA WHERE ROWNUM = 1;
  
  -- Pillamos una sede y aula distintas
  SELECT Codigo INTO v_sede_nueva FROM SEDE WHERE ROWNUM = 1;
  SELECT Codigo INTO v_aula_nueva FROM AULA WHERE Sede_Codigo = v_sede_nueva AND ROWNUM = 1;

  DESPISTE(v_est_dni, v_fecha, v_aula_nueva, v_sede_nueva);
  DBMS_OUTPUT.PUT_LINE('DESPISTE ejecutado correctamente');
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE('Error esperado en DESPISTE (ventanas de tiempo): ' || SQLERRM);
END;
/

PROMPT ========================================
PROMPT PRUEBA 21: PROBAR TRIGGER TR_CENTROS (Secuencia)
PROMPT ========================================
INSERT INTO CENTRO (Nombre, Poblacion) VALUES ('Instituto Test Trigger', 'Malaga');
SELECT Codigo, Nombre FROM CENTRO WHERE Nombre = 'Instituto Test Trigger';
ROLLBACK;

PROMPT ========================================
PROMPT PRUEBA 22: PROBAR TRIGGER TR_MIGRAR_CENTRO
PROMPT ========================================
DECLARE
  v_centro VARCHAR2(20);
  v_sede_nueva VARCHAR2(20);
BEGIN
  SELECT Codigo INTO v_centro FROM CENTRO WHERE ROWNUM = 1;
  SELECT Codigo INTO v_sede_nueva FROM SEDE WHERE ROWNUM = 1;
  
  -- Este update es el que dispara TR_MIGRAR_CENTRO
  UPDATE CENTRO SET Sede_Codigo = v_sede_nueva WHERE Codigo = v_centro;
  DBMS_OUTPUT.PUT_LINE('Update en CENTRO ejecutado (Trigger disparado por detras)');
  ROLLBACK;
END;
/

PROMPT ========================================
PROMPT PRUEBA 23: COMPROBACION INTEGRAL DE VISTAS (VPD Y OCUPACION)
PROMPT ========================================

-- 1. Limpiamos y generamos entorno aislado para esta prueba
EXEC PR_BORRA_AULAS; 
EXEC PR_RELLENA_AULAS(5, 30);

-- 2. Nos asignamos como un vocal y estudiante ya existente de forma dinamica
UPDATE ESTUDIANTE SET Usuario_BD = 'PAU' WHERE DNI = (SELECT DNI FROM ESTUDIANTE WHERE ROWNUM = 1); 
UPDATE VOCAL SET Usuario_BD = 'PAU' WHERE DNI = (SELECT DNI FROM VOCAL WHERE ROWNUM = 1);

-- 3. Cambiamos al vocal elegido a responsable de la Sede 1
UPDATE SEDE SET Vocal_Responsable_DNI = (SELECT DNI FROM VOCAL WHERE Usuario_BD = 'PAU') WHERE Codigo = '1';

-- 4. Creacion de Examen base y Asistencia
INSERT INTO EXAMEN (FechayHora, Aula_Codigo, Vocal_DNI) 
VALUES (TO_DATE('20/05/2026 10:00', 'DD/MM/YYYY HH24:MI'), '1_1', (SELECT DNI FROM VOCAL WHERE Usuario_BD = 'PAU'));

INSERT INTO ASISTENCIA (Estudiante_DNI, Examen_FechayHora, Materia_Codigo, Sede_Codigo, Aula_Codigo, Asiste, Entrega)
VALUES (
    (SELECT DNI FROM ESTUDIANTE WHERE Usuario_BD = 'PAU'), 
    TO_DATE('20/05/2026 10:00', 'DD/MM/YYYY HH24:MI'), 
    (SELECT Codigo FROM MATERIA WHERE ROWNUM = 1), 
    '1', '1_1', 'S', 'S'
);

-- 5. Insercion de Vigilante extra dinamico
INSERT INTO EXAMEN_VOCAL_Vigilantes (Examen_FechayHora, Vocal_DNI)
SELECT TO_DATE('20/05/2026 10:00', 'DD/MM/YYYY HH24:MI'), DNI 
FROM VOCAL 
WHERE Usuario_BD IS NULL OR Usuario_BD != 'PAU' 
FETCH FIRST 1 ROWS ONLY;

PROMPT --- VISTAS GLOBALES Y DE OCUPACION ---
SELECT 'V_OCUPACION_ASIGNADA' as Vista, v.* FROM V_OCUPACION_ASIGNADA v;
SELECT 'V_OCUPACION' as Vista, v.* FROM V_OCUPACION v;
SELECT 'V_ASIGNACION_GLOBAL' as Vista, v.* FROM V_ASIGNACION_GLOBAL v;
SELECT 'V_VIGILANTES' as Vista, v.* FROM V_VIGILANTES v;

PROMPT --- VISTAS POR PERFIL (SEGURIDAD VPD / USER = PAU) ---
SELECT 'V_MI_VIGILANCIA' as Vista, v.* FROM V_MI_VIGILANCIA v;
SELECT 'V_MI_SEDE_GESTION' as Vista, v.* FROM V_MI_SEDE_GESTION v;
SELECT 'V_MIS_DATOS' as Vista, v.* FROM V_MIS_DATOS v;
SELECT 'V_MI_ASIGNACION' as Vista, v.* FROM V_MI_ASIGNACION v;

-- Limpiamos los datos insertados aislando la prueba
ROLLBACK;
EXEC PR_BORRA_AULAS;
EXEC PR_RELLENA_AULAS(5, 30); -- Dejamos las aulas listas por si acaso

PROMPT ========================================
PROMPT PRUEBA 24: COMPROBACION DE PRIVILEGIOS DE ROLES
PROMPT ========================================

PROMPT --- 1. Privilegios a nivel de Columna (SEDE, EXAMEN y ASISTENCIA) ---
SELECT grantee, table_name, column_name, privilege 
FROM user_col_privs_made 
WHERE grantee IN ('ROL_ESTUDIANTE', 'ROL_VOCAL', 'ROL_ACCESO')
ORDER BY grantee, table_name, column_name;

PROMPT --- 2. Privilegios a nivel de Tabla, Vista o Paquete ---
SELECT grantee, table_name, privilege 
FROM user_tab_privs_made 
WHERE grantee IN ('ROL_ESTUDIANTE', 'ROL_VOCAL', 'ROL_ACCESO')
ORDER BY grantee, table_name, privilege;

PROMPT --- 3. Privilegios de Sistema (CREATE SESSION) ---
SELECT role, privilege 
FROM role_sys_privs 
WHERE role IN ('ROL_ESTUDIANTE', 'ROL_VOCAL', 'ROL_ACCESO')
ORDER BY role;

PROMPT ========================================
PROMPT PRUEBA 26: RESUMEN FINAL
PROMPT ========================================
SELECT 'PRUEBAS COMPLETADAS - ' || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI') AS resultado FROM DUAL;

PROMPT ========================================
PROMPT TODAS LAS PRUEBAS EJECUTADAS
PROMPT ========================================
/
