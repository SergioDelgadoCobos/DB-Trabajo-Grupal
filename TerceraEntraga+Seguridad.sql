-- ============================================================================
-- BASES DE DATOS II -- TRABAJO GRUPO PAU
-- TERCERA ENTREGA: OCUPACION, SEGURIDAD, TRIGGERS + RUBRICA
-- Universidad de Malaga -- ETSI Informatica -- 2025-26
-- ============================================================================
-- INSTRUCCIONES:
--   1. Ejecutar despues de SegundaEntrega.sql
--   2. Conectarse como SYS
-- ============================================================================

ALTER SESSION SET CURRENT_SCHEMA = PAU;

-- Vistas de Ocupación
CREATE OR REPLACE VIEW V_OCUPACION_ASIGNADA AS
SELECT 
    S.Codigo AS Sede_Codigo,
    S.Nombre AS Sede_Nombre,
    E.Aula_Codigo,
    E.FechayHora AS Fecha_Examen,
    COUNT(A.Estudiante_DNI) AS Numero_Estudiantes_Asignados
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN ASISTENCIA A ON E.FechayHora = A.Examen_FechayHora
GROUP BY 
    S.Codigo, 
    S.Nombre, 
    E.Aula_Codigo, 
    E.FechayHora;

CREATE OR REPLACE VIEW V_OCUPACION AS
SELECT 
    S.Codigo AS Sede_Codigo,
    S.Nombre AS Sede_Nombre,
    E.Aula_Codigo,
    E.FechayHora AS Fecha_Examen,
    COUNT(A.Estudiante_DNI) AS Numero_Estudiantes_Asisten
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN ASISTENCIA A ON E.FechayHora = A.Examen_FechayHora
WHERE A.Asiste = 'S' 
GROUP BY 
    S.Codigo, 
    S.Nombre, 
    E.Aula_Codigo, 
    E.FechayHora;

CREATE OR REPLACE VIEW V_VIGILANTES AS
SELECT 
    S.Codigo AS Sede_Codigo,
    S.Nombre AS Sede_Nombre,
    E.Aula_Codigo,
    E.FechayHora AS Fecha_Examen,
    COUNT(V.Vocal_DNI) AS Numero_Vigilantes
FROM SEDE S
JOIN AULA AU ON S.Codigo = AU.Sede_Codigo
JOIN EXAMEN E ON AU.Codigo = E.Aula_Codigo
JOIN EXAMEN_VOCAL_Vigilantes V ON E.FechayHora = V.Examen_FechayHora
GROUP BY 
    S.Codigo, 
    S.Nombre, 
    E.Aula_Codigo, 
    E.FechayHora;

-- Paquete PK_OCUPACION
CREATE OR REPLACE PACKAGE PK_OCUPACION AS
    FUNCTION OCUPACION_MAXIMA(p_sede IN VARCHAR2, p_aula IN VARCHAR2) RETURN NUMBER;
    FUNCTION OCUPACION_OK RETURN BOOLEAN;
    FUNCTION VOCAL_DUPLICADO(p_vocal_dni IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION VOCALES_DUPLICADOS RETURN BOOLEAN;
    FUNCTION VOCAL_RATIO(p_ratio IN NUMBER) RETURN BOOLEAN;
END PK_OCUPACION;
/

CREATE OR REPLACE PACKAGE BODY PK_OCUPACION AS

    -- 1. OCUPACION_MAXIMA
    FUNCTION OCUPACION_MAXIMA(p_sede IN VARCHAR2, p_aula IN VARCHAR2) RETURN NUMBER AS
        v_max_personas NUMBER;
    BEGIN
        SELECT NVL(MAX(
            -- Total de alumnos asignados al examen en ese aula
            (SELECT COUNT(*) FROM ASISTENCIA WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = p_aula) +
            -- Total de vocales (Principal + Vigilantes) en ese aula 
            (SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes WHERE Examen_FechayHora = E.FechayHora
            ))
        ), 0)
        INTO v_max_personas
        FROM EXAMEN E
        JOIN AULA A ON E.Aula_Codigo = A.Codigo
        WHERE A.Sede_Codigo = p_sede AND A.Codigo = p_aula;

        RETURN v_max_personas;
    END OCUPACION_MAXIMA;

    -- 2. OCUPACION_OK
    FUNCTION OCUPACION_OK RETURN BOOLEAN AS
        v_infracciones NUMBER;
    BEGIN
        -- Buscamos si existe ALGÚN examen futuro que incumpla las condiciones
        SELECT COUNT(*) INTO v_infracciones
        FROM EXAMEN E
        JOIN AULA A ON E.Aula_Codigo = A.Codigo
        WHERE E.FechayHora > SYSDATE
        AND (
            -- Alumnos asignados superan la Capacidad_Examen
            (SELECT COUNT(*) FROM ASISTENCIA WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo) > A.Capacidad_Examen
            OR
            -- Personas totales (Alumnos + Vocales) superan la Capacidad total del aula
            ((SELECT COUNT(*) FROM ASISTENCIA WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo) +
             (SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes WHERE Examen_FechayHora = E.FechayHora
             ))) > A.Capacidad
        );

        -- Si no hay infracciones (v_infracciones = 0), devuelve TRUE
        RETURN (v_infracciones = 0);
    END OCUPACION_OK;

    -- 3. VOCAL_DUPLICADO
    FUNCTION VOCAL_DUPLICADO(p_vocal_dni IN VARCHAR2) RETURN BOOLEAN AS
        v_max_asignaciones NUMBER;
    BEGIN
        SELECT NVL(MAX(num_asignaciones), 0) INTO v_max_asignaciones
        FROM (
            SELECT FechayHora, COUNT(DISTINCT Aula_Codigo) as num_asignaciones
            FROM (
                -- Recopilamos todos los exámenes donde el vocal participe (principal o vigilante)
                SELECT FechayHora, Aula_Codigo, Vocal_DNI FROM EXAMEN
                UNION
                SELECT E.FechayHora, E.Aula_Codigo, V.Vocal_DNI
                FROM EXAMEN_VOCAL_Vigilantes V
                JOIN EXAMEN E ON V.Examen_FechayHora = E.FechayHora
            )
            WHERE Vocal_DNI = p_vocal_dni
            GROUP BY FechayHora
        );

        -- Devuelve TRUE si está asignado a más de un examen en la misma franja
        RETURN (v_max_asignaciones > 1);
    END VOCAL_DUPLICADO;

    -- 4. VOCALES_DUPLICADOS
    FUNCTION VOCALES_DUPLICADOS RETURN BOOLEAN AS
        v_max_global NUMBER;
    BEGIN
        SELECT NVL(MAX(num_asignaciones), 0) INTO v_max_global
        FROM (
            SELECT Vocal_DNI, FechayHora, COUNT(DISTINCT Aula_Codigo) as num_asignaciones
            FROM (
                SELECT FechayHora, Aula_Codigo, Vocal_DNI FROM EXAMEN
                UNION
                SELECT E.FechayHora, E.Aula_Codigo, V.Vocal_DNI
                FROM EXAMEN_VOCAL_Vigilantes V
                JOIN EXAMEN E ON V.Examen_FechayHora = E.FechayHora
            )
            GROUP BY Vocal_DNI, FechayHora
        );

        -- Devuelve TRUE si ALGÚN vocal supera una asignación simultánea
        RETURN (v_max_global > 1);
    END VOCALES_DUPLICADOS;

    -- 5. VOCAL_RATIO 
    FUNCTION VOCAL_RATIO(p_ratio IN NUMBER) RETURN BOOLEAN AS
        v_infracciones NUMBER;
    BEGIN
        -- Buscamos si hay algún examen futuro donde los alumnos superen el ratio esperado 
        SELECT COUNT(*) INTO v_infracciones
        FROM EXAMEN E
        WHERE E.FechayHora > SYSDATE
        AND (
            SELECT COUNT(*) FROM ASISTENCIA WHERE Examen_FechayHora = E.FechayHora AND Aula_Codigo = E.Aula_Codigo
        ) > p_ratio * (
            SELECT COUNT(*) FROM (
                SELECT Vocal_DNI FROM EXAMEN WHERE FechayHora = E.FechayHora
                UNION
                SELECT Vocal_DNI FROM EXAMEN_VOCAL_Vigilantes WHERE Examen_FechayHora = E.FechayHora
            )
        );

        -- Si no hay infracciones en ningún examen futuro, devuelve TRUE 
        RETURN (v_infracciones = 0);
    END VOCAL_RATIO;

END PK_OCUPACION;
/

-- Seguridad
-- Modificamos las tablas para almacenar el usuario de base de datos generado
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ESTUDIANTE ADD Usuario_BD VARCHAR2(30)'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE VOCAL ADD Usuario_BD VARCHAR2(30)'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

GRANT CREATE SEQUENCE TO PAU;

BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ESTUDIANTE'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_VOCAL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP ROLE ROL_ACCESO'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Creamos los roles
CREATE ROLE ROL_ESTUDIANTE;
CREATE ROLE ROL_VOCAL;

-- Damos permiso de conexión a los roles
GRANT CREATE SESSION TO ROL_ESTUDIANTE;
GRANT CREATE SESSION TO ROL_VOCAL;

-- Opcional: Asignar permisos de lectura sobre las vistas/tablas que les correspondan
GRANT SELECT ON V_OCUPACION_ASIGNADA TO ROL_ESTUDIANTE;
GRANT SELECT ON EXAMEN TO ROL_VOCAL;

-- Paquete PK_SEGURIDAD_PAU
CREATE OR REPLACE PACKAGE PK_SEGURIDAD_PAU AS
    PROCEDURE PR_CREA_ESTUDIANTE(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2);
    PROCEDURE PR_CREA_VOCAL(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2);
END PK_SEGURIDAD_PAU;
/

CREATE OR REPLACE PACKAGE BODY PK_SEGURIDAD_PAU AS

    PROCEDURE PR_CREA_ESTUDIANTE(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2
    ) AS
        v_count NUMBER;
    BEGIN
        -- 1. Comprobar que el estudiante existe en la tabla
        SELECT COUNT(*) INTO v_count FROM ESTUDIANTE WHERE DNI = p_dni;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'El estudiante con DNI ' || p_dni || ' no existe.');
        END IF;

        -- 2. Generar el nombre de usuario y la contraseña aleatoria
        p_usuario := 'EST_' || p_dni;
        -- 'X' genera caracteres alfanuméricos en mayúsculas y números
        p_password := DBMS_RANDOM.STRING('X', 10);

        -- 3. Crear el usuario en Oracle usando SQL Dinámico (asignamos al tablespace TS_PAU)
        EXECUTE IMMEDIATE 'CREATE USER ' || p_usuario || 
                          ' IDENTIFIED BY "' || p_password || '"' ||
                          ' DEFAULT TABLESPACE TS_PAU';
        
        -- 4. Asignar el rol al usuario 
        EXECUTE IMMEDIATE 'GRANT ROL_ESTUDIANTE TO ' || p_usuario;

        -- 5. Guardar el nombre de usuario en la tabla ESTUDIANTE
        UPDATE ESTUDIANTE SET Usuario_BD = p_usuario WHERE DNI = p_dni;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_CREA_ESTUDIANTE;


    PROCEDURE PR_CREA_VOCAL(
        p_dni VARCHAR2, p_usuario OUT VARCHAR2, p_password OUT VARCHAR2
    ) AS
        v_count NUMBER;
    BEGIN
        -- 1. Comprobar que el vocal existe en la tabla
        SELECT COUNT(*) INTO v_count FROM VOCAL WHERE DNI = p_dni;
        IF v_count = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El vocal con DNI ' || p_dni || ' no existe.');
        END IF;

        -- 2. Generar el nombre de usuario y la contraseña aleatoria
        p_usuario := 'VOC_' || p_dni;
        p_password := DBMS_RANDOM.STRING('X', 10);

        -- 3. Crear el usuario en Oracle
        EXECUTE IMMEDIATE 'CREATE USER ' || p_usuario || 
                          ' IDENTIFIED BY "' || p_password || '"' ||
                          ' DEFAULT TABLESPACE TS_PAU';
        
        -- 4. Asignar el rol al usuario 
        EXECUTE IMMEDIATE 'GRANT ROL_VOCAL TO ' || p_usuario;

        -- 5. Guardar el nombre de usuario en la tabla VOCAL
        UPDATE VOCAL SET Usuario_BD = p_usuario WHERE DNI = p_dni;
        
        COMMIT;
        
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_CREA_VOCAL;

END PK_SEGURIDAD_PAU;
/

-- Trigger TR_BORRA_AULA
CREATE OR REPLACE TRIGGER TR_BORRA_AULA
BEFORE DELETE ON AULA
FOR EACH ROW
DECLARE
    v_examenes_invalidos NUMBER;
BEGIN
    -- a. Comprobamos si hay exámenes ya realizados o planificados en las próximas 48 horas
    -- La condición < (SYSDATE + 2) cubre tanto los pasados (que son menores a SYSDATE) 
    -- como los de las próximas 48 horas.
    SELECT COUNT(*)
    INTO v_examenes_invalidos
    FROM EXAMEN
    WHERE Aula_Codigo = :OLD.Codigo
      AND FechayHora < (SYSDATE + 2); 

    -- Si hay al menos un examen que incumple la condición, bloqueamos el borrado
    IF v_examenes_invalidos > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Error: No se puede borrar el aula. Tiene exámenes ya realizados o planificados para las próximas 48 horas.');
    ELSE
        -- b. Si no hay conflicto, el borrado del aula implica borrar los exámenes planificados (los de > 48h)
        -- Primero borramos los registros dependientes para no violar las Foreing Keys
        
        DELETE FROM ASISTENCIA 
        WHERE Examen_FechayHora IN (SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        
        DELETE FROM EXAMEN_MATERIA 
        WHERE Examen_FechayHora IN (SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        
        DELETE FROM EXAMEN_VOCAL_Vigilantes 
        WHERE Examen_FechayHora IN (SELECT FechayHora FROM EXAMEN WHERE Aula_Codigo = :OLD.Codigo);
        
        -- Finalmente, borramos los exámenes futuros planificados en el aula
        DELETE FROM EXAMEN 
        WHERE Aula_Codigo = :OLD.Codigo;
    END IF;
END TR_BORRA_AULA;
/

-- Procedimientos adicionales
-- Añadimos las columnas requeridas por el enunciado a la tabla ASISTENCIA
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA ADD Aula_Codigo VARCHAR2(20)'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA ADD Sede_Codigo VARCHAR2(20)'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- Procedimiento DESPISTE
CREATE OR REPLACE PROCEDURE DESPISTE(
    p_dni VARCHAR2, p_examen_fecha DATE,
    p_aula_nueva VARCHAR2, p_sede_nueva VARCHAR2
) AS
    v_primera_hora DATE;
    v_aula_libre VARCHAR2(20);
BEGIN
    SELECT MIN(Examen_FechayHora) INTO v_primera_hora
    FROM ASISTENCIA
    WHERE Estudiante_DNI = p_dni
      AND TRUNC(Examen_FechayHora) = TRUNC(p_examen_fecha);

    IF v_primera_hora IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'No se encontraron examenes para esa fecha.');
    END IF;

    IF NOT (v_primera_hora BETWEEN SYSDATE AND (SYSDATE + 1/24)) THEN
        RAISE_APPLICATION_ERROR(-20001, 'Fuera de ventana de reubicacion (1h).');
    END IF;

    UPDATE ASISTENCIA
    SET Aula_Codigo = p_aula_nueva, Sede_Codigo = p_sede_nueva
    WHERE Estudiante_DNI = p_dni AND Examen_FechayHora = v_primera_hora;

    FOR rec IN (
        SELECT Examen_FechayHora, Materia_Codigo
        FROM ASISTENCIA
        WHERE Estudiante_DNI = p_dni
          AND TRUNC(Examen_FechayHora) = TRUNC(p_examen_fecha)
          AND Examen_FechayHora > v_primera_hora
    ) LOOP
        BEGIN
            SELECT A.Codigo INTO v_aula_libre
            FROM AULA A
            WHERE A.Sede_Codigo = p_sede_nueva
              AND A.Capacidad_Examen > (
                  SELECT COUNT(*)
                  FROM ASISTENCIA AST
                  WHERE AST.Aula_Codigo = A.Codigo
                    AND AST.Examen_FechayHora = rec.Examen_FechayHora
              )
            AND ROWNUM = 1;

            UPDATE ASISTENCIA
            SET Aula_Codigo = v_aula_libre, Sede_Codigo = p_sede_nueva
            WHERE Estudiante_DNI = p_dni
              AND Examen_FechayHora = rec.Examen_FechayHora
              AND Materia_Codigo = rec.Materia_Codigo;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20002,
                  'No hay aulas libres en sede destino.');
        END;
    END LOOP;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END DESPISTE;
/

-- Procedimiento MIGRAR_CENTRO
CREATE OR REPLACE PROCEDURE MIGRAR_CENTRO(
    p_centro VARCHAR2, p_sede_origen VARCHAR2, p_sede_destino VARCHAR2
) AS
    v_aula_libre VARCHAR2(20);
BEGIN
    -- Recorremos todos los alumnos del centro que tienen exámenes en la sede de origen
    FOR rec_asistencia IN (
        SELECT AST.Estudiante_DNI, AST.Examen_FechayHora, AST.Materia_Codigo
        FROM ASISTENCIA AST
        JOIN ESTUDIANTE E ON AST.Estudiante_DNI = E.DNI
        WHERE E.Centro_Codigo = p_centro
          AND AST.Sede_Codigo = p_sede_origen
    ) LOOP
        
        -- Buscamos un aula en la sede destino para esa fecha/hora que no supere su Capacidad_Examen
        BEGIN
            SELECT A.Codigo INTO v_aula_libre
            FROM AULA A
            WHERE A.Sede_Codigo = p_sede_destino
              AND A.Capacidad_Examen > (
                  SELECT COUNT(*) 
                  FROM ASISTENCIA AST_SUB
                  WHERE AST_SUB.Aula_Codigo = A.Codigo 
                    AND AST_SUB.Examen_FechayHora = rec_asistencia.Examen_FechayHora
              )
            AND ROWNUM = 1;

            -- Movemos al alumno al nuevo aula/sede
            UPDATE ASISTENCIA
            SET Sede_Codigo = p_sede_destino,
                Aula_Codigo = v_aula_libre
            WHERE Estudiante_DNI = rec_asistencia.Estudiante_DNI 
              AND Examen_FechayHora = rec_asistencia.Examen_FechayHora
              AND Materia_Codigo = rec_asistencia.Materia_Codigo;
              
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- c. Si no es posible realizar la asignación, lanza excepción y aborta la transacción
                RAISE_APPLICATION_ERROR(-20003, 'Error de migración: No hay capacidad suficiente en las aulas de la sede destino.');
        END;
    END LOOP;
END MIGRAR_CENTRO;
/

-- Trigger TR_MIGRAR_CENTRO
CREATE OR REPLACE TRIGGER TR_MIGRAR_CENTRO
AFTER UPDATE OF Sede_Codigo ON CENTRO
FOR EACH ROW
BEGIN
    -- Solo migramos si el centro ya tenía una sede previa asignada y se está cambiando a una distinta
    IF :OLD.Sede_Codigo IS NOT NULL AND :OLD.Sede_Codigo <> :NEW.Sede_Codigo THEN
        MIGRAR_CENTRO(:NEW.Codigo, :OLD.Sede_Codigo, :NEW.Sede_Codigo);
    END IF;
END TR_MIGRAR_CENTRO;
/

-- Vista para que el estudiante vea sus asignaturas, fechas, sede y aula
CREATE OR REPLACE VIEW V_MI_ASIGNACION AS
SELECT a.Materia_Codigo, a.Examen_FechayHora, a.Sede_Codigo, a.Aula_Codigo
FROM ASISTENCIA a
JOIN ESTUDIANTE e ON a.Estudiante_DNI = e.DNI
WHERE e.Usuario_BD = USER; -- Filtra por el usuario logueado en Oracle

-- Vista para que vea sus datos personales
CREATE OR REPLACE VIEW V_MIS_DATOS AS
SELECT DNI, Nombre, Apellidos, Telefono, Correo, Centro_Codigo 
FROM ESTUDIANTE
WHERE Usuario_BD = USER;

-- Damos permisos al rol
GRANT SELECT ON V_MI_ASIGNACION TO ROL_ESTUDIANTE;
GRANT SELECT ON V_MIS_DATOS TO ROL_ESTUDIANTE;

-- Añadimos la columna a la tabla física
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE EXAMEN ADD Num_Estudiantes_Presentes NUMBER'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'ALTER TABLE EXAMEN DROP CONSTRAINT CHK_EXAMEN_NUM_EST'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
ALTER TABLE EXAMEN ADD CONSTRAINT CHK_EXAMEN_NUM_EST
  CHECK (Num_Estudiantes_Presentes >= 0);

CREATE OR REPLACE VIEW V_MI_VIGILANCIA AS
SELECT 
    e.FechayHora, 
    e.Aula_Codigo, 
    'PRINCIPAL' as Rol_Vigilancia,
    e.Num_Estudiantes_Presentes -- Campo nuevo para el conteo manual
FROM EXAMEN e
JOIN VOCAL v ON e.Vocal_DNI = v.DNI
WHERE v.Usuario_BD = USER
UNION
SELECT 
    ev.Examen_FechayHora, 
    ex.Aula_Codigo, 
    'VIGILANTE',
    NULL -- Un vigilante raso no tiene por qué editar esto
FROM EXAMEN_VOCAL_Vigilantes ev
JOIN EXAMEN ex ON ev.Examen_FechayHora = ex.FechayHora
JOIN VOCAL v ON ev.Vocal_DNI = v.DNI
WHERE v.Usuario_BD = USER;

-- Damos permiso para que el rol vocal pueda modificar solo ese dato en la tabla base
GRANT UPDATE (Num_Estudiantes_Presentes) ON EXAMEN TO ROL_VOCAL;
GRANT SELECT ON V_MI_VIGILANCIA TO ROL_VOCAL;

-- Como el responsable de aula debe poder introducir si el alumno asiste o no:
-- Le damos permiso de UPDATE solo sobre el campo 'Asiste' de la tabla ASISTENCIA
GRANT UPDATE (Asiste) ON ASISTENCIA TO ROL_VOCAL;

CREATE OR REPLACE VIEW V_MI_SEDE_GESTION AS
SELECT s.Codigo, s.Nombre, s.Tipo
FROM SEDE s
JOIN VOCAL v ON s.Vocal_Responsable_DNI = v.DNI
WHERE v.Usuario_BD = USER;

-- Damos permisos totales sobre esta vista al rol vocal
GRANT SELECT, INSERT, UPDATE, DELETE ON V_MI_SEDE_GESTION TO ROL_VOCAL;

-- Vista global de asignación para el Servicio de Acceso
CREATE OR REPLACE VIEW V_ASIGNACION_GLOBAL AS
SELECT 
    c.Nombre AS Centro_Nombre,
    e.Nombre || ' ' || e.Apellidos AS Estudiante,
    s.Nombre AS Sede_Nombre,
    a.Aula_Codigo,
    a.Examen_FechayHora
FROM ASISTENCIA a
JOIN ESTUDIANTE e ON a.Estudiante_DNI = e.DNI
JOIN CENTRO c ON e.Centro_Codigo = c.Codigo
JOIN SEDE s ON a.Sede_Codigo = s.Codigo;

-- ============================================================================
-- ROL ACCESO Y PERMISOS
-- ============================================================================

CREATE ROLE ROL_ACCESO;
GRANT CREATE SESSION TO ROL_ACCESO;
GRANT SELECT ON V_ASIGNACION_GLOBAL TO ROL_ACCESO;
GRANT EXECUTE ON PK_ASIGNA TO ROL_ACCESO;
GRANT SELECT ON V_OCUPACION_ASIGNADA TO ROL_ACCESO;
GRANT SELECT ON V_OCUPACION TO ROL_ACCESO;
GRANT SELECT ON V_VIGILANTES TO ROL_ACCESO;
GRANT UPDATE (Vocal_Responsable_DNI, Vocal_Secretario_DNI) ON SEDE TO ROL_ACCESO;


-- ============================================================================
-- SEGURIDAD: Politicas, auditoria, restricciones
-- ============================================================================

-- Politica de contraseñas
ALTER PROFILE DEFAULT LIMIT
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LIFE_TIME    30
  PASSWORD_GRACE_TIME   5
  PASSWORD_LOCK_TIME    1;

-- Validacion DNI
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ESTUDIANTE DROP CONSTRAINT CHK_ESTUDIANTE_DNI_FORMAT'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE VOCAL DROP CONSTRAINT CHK_VOCAL_DNI_FORMAT'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
ALTER TABLE ESTUDIANTE ADD CONSTRAINT CHK_ESTUDIANTE_DNI_FORMAT
  CHECK (REGEXP_LIKE(DNI, '^[0-9]{8}[A-Z]$')) NOVALIDATE;

ALTER TABLE VOCAL ADD CONSTRAINT CHK_VOCAL_DNI_FORMAT
  CHECK (REGEXP_LIKE(DNI, '^[0-9]{8}[A-Z]$')) NOVALIDATE;

-- VPD para estudiantes
CREATE OR REPLACE FUNCTION FN_ESTUDIANTE_VPD(
  p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 AS
BEGIN
  RETURN 'Usuario_BD = USER';
END;
/

BEGIN
  DBMS_RLS.DROP_POLICY(
    object_schema => 'PAU',
    object_name   => 'ESTUDIANTE',
    policy_name   => 'POL_ESTUDIANTE_VPD'
  );
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
  DBMS_RLS.ADD_POLICY(
    object_schema => 'PAU',
    object_name   => 'ESTUDIANTE',
    policy_name   => 'POL_ESTUDIANTE_VPD',
    function_schema => 'PAU',
    policy_function => 'FN_ESTUDIANTE_VPD'
  );
END;
/

-- Auditoria unificada (Oracle 23ai)
BEGIN
  EXECUTE IMMEDIATE 'NOAUDIT POLICY audit_asistencia_updates';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
  EXECUTE IMMEDIATE 'DROP AUDIT POLICY audit_asistencia_updates';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE AUDIT POLICY audit_asistencia_updates
  ACTIONS UPDATE ON PAU.ASISTENCIA;
AUDIT POLICY audit_asistencia_updates;


-- ============================================================================
-- RUBRICA: RESTRICCIONES ADICIONALES
-- ============================================================================

BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA DROP CONSTRAINT CHK_ASISTENCIA_ASISTE_VALUES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE ASISTENCIA DROP CONSTRAINT CHK_ASISTENCIA_ENTREGA_VALUES'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'ALTER TABLE CENTRO DROP CONSTRAINT CHK_CENTRO_NOMBRE_NOT_NULL'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

ALTER TABLE ASISTENCIA ADD CONSTRAINT CHK_ASISTENCIA_ASISTE_VALUES
  CHECK (Asiste IN ('S', 'N'));

ALTER TABLE ASISTENCIA ADD CONSTRAINT CHK_ASISTENCIA_ENTREGA_VALUES
  CHECK (Entrega IN ('S', 'N'));

ALTER TABLE CENTRO ADD CONSTRAINT CHK_CENTRO_NOMBRE_NOT_NULL
  CHECK (Nombre IS NOT NULL);


-- ============================================================================
-- COMPROBACIONES FINALES
-- ============================================================================

SELECT 'TABLAS' AS tipo, COUNT(*) AS total FROM user_tables
UNION ALL
SELECT 'INDICES', COUNT(*) FROM user_indexes
UNION ALL
SELECT 'VISTAS', COUNT(*) FROM user_views
UNION ALL
SELECT 'PROCEDIMIENTOS', COUNT(*) FROM user_objects WHERE object_type = 'PROCEDURE'
UNION ALL
SELECT 'PAQUETES', COUNT(*) FROM user_objects WHERE object_type = 'PACKAGE'
UNION ALL
SELECT 'TRIGGERS', COUNT(*) FROM user_triggers;

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
PROMPT TERCERA ENTREGA COMPLETADA
PROMPT ========================================