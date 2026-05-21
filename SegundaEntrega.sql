-- ============================================================================
-- BASES DE DATOS II -- TRABAJO GRUPO PAU
-- SEGUNDA ENTREGA: INDICES, MV, CENTROS, ASIGNACION
-- Universidad de Malaga -- ETSI Informatica -- 2025-26
-- ============================================================================
-- INSTRUCCIONES:
--   1. Ejecutar despues de PrimeraEntrega.sql
--   2. Conectarse como SYS (excepto donde se indique)
-- ============================================================================

-- Reconstruir indices existentes en TS_INDICES
DECLARE
  CURSOR c_indices IS
    SELECT index_name FROM user_indexes
    WHERE tablespace_name != 'TS_INDICES' OR tablespace_name IS NULL;
BEGIN
  FOR idx IN c_indices LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER INDEX ' || idx.index_name || ' REBUILD TABLESPACE TS_INDICES';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

-- Indices adicionales
CREATE INDEX IDX_ESTUDIANTE_APELLIDOS_UP
  ON ESTUDIANTE (UPPER(Apellidos)) TABLESPACE TS_INDICES;
CREATE INDEX IDX_ESTUDIANTE_CORREO
  ON ESTUDIANTE (Correo) TABLESPACE TS_INDICES;
CREATE BITMAP INDEX IDX_ESTUDIANTE_CENTRO_BM
  ON ESTUDIANTE (Centro_Codigo) TABLESPACE TS_INDICES;

-- Indices para busquedas frecuentes
CREATE INDEX IDX_ASISTENCIA_EST
  ON ASISTENCIA (Estudiante_DNI) TABLESPACE TS_INDICES;
CREATE INDEX IDX_ASISTENCIA_EXAMEN
  ON ASISTENCIA (Examen_FechayHora) TABLESPACE TS_INDICES;

-- Secuencia y trigger para centros
CREATE SEQUENCE SEQ_CENTROS;

CREATE OR REPLACE TRIGGER tr_centros
BEFORE INSERT ON CENTRO
FOR EACH ROW
BEGIN
    IF :new.Codigo IS NULL THEN
        :new.Codigo := TO_CHAR(SEQ_CENTROS.NEXTVAL);
    END IF;
END tr_centros;
/


-- ============================================================================
-- POBLAR CENTROS Y ESTUDIANTES
-- ============================================================================

-- Insertar centros desde la vista
INSERT INTO CENTRO (Nombre)
SELECT DISTINCT centro FROM v_estudiantes;

COMMIT;

-- Insertar estudiantes desde la vista
INSERT INTO ESTUDIANTE (DNI, Nombre, Apellidos, Telefono, Correo, Centro_Codigo)
SELECT
    v.dni,
    v.nombre,
    v.apellidos,
    v.telefono,
    v.correo,
    c.Codigo
FROM V_ESTUDIANTES v
JOIN CENTRO c ON UPPER(v.centro) = UPPER(c.Nombre);

COMMIT;

-- Matricular estudiantes
EXEC PR_MATRICULA_ESTUDIANTES;

-- Vista materializada y sinonimo
CONNECT pau/pau@FREEPDB1

CREATE MATERIALIZED VIEW VM_ESTUDIANTES
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
START WITH TRUNC(SYSDATE + 1)
NEXT TRUNC(SYSDATE + 1)
AS
SELECT e.DNI, e.Nombre, e.Apellidos, e.Telefono, e.Correo, c.Nombre AS Centro
FROM PAU.ESTUDIANTE e
JOIN PAU.CENTRO c ON e.Centro_Codigo = c.Codigo;

CREATE PUBLIC SYNONYM S_ESTUDIANTES FOR VM_ESTUDIANTES;

CONNECT sys/oracle@FREEPDB1 as sysdba
ALTER SESSION SET CURRENT_SCHEMA = PAU;


-- ============================================================================
-- PAQUETE PK_ASIGNA
-- ============================================================================

CREATE OR REPLACE PACKAGE PK_ASIGNA AS
    FUNCTION F_PLAZAS(PSEDE IN VARCHAR2) RETURN NUMBER;
    PROCEDURE PR_ASIGNA_SEDE;
END PK_ASIGNA;
/

CREATE OR REPLACE PACKAGE BODY PK_ASIGNA AS

    FUNCTION F_PLAZAS(PSEDE IN VARCHAR2) RETURN NUMBER AS
        v_capacidad NUMBER;
        v_estudiantes NUMBER;
    BEGIN
        SELECT NVL(SUM(CAPACIDAD_EXAMEN), 0) INTO v_capacidad
        FROM AULA WHERE SEDE_CODIGO = PSEDE;

        SELECT NVL(COUNT(*), 0) INTO v_estudiantes
        FROM ESTUDIANTE e
        JOIN CENTRO c ON e.CENTRO_CODIGO = c.CODIGO
        WHERE c.SEDE_CODIGO = PSEDE;

        RETURN v_capacidad - v_estudiantes;
    END F_PLAZAS;

    PROCEDURE PR_ASIGNA_SEDE AS
        e_sin_espacio EXCEPTION;

        CURSOR c_centros_pendientes IS
            SELECT c.CODIGO, COUNT(e.DNI) as total_estudiantes
            FROM CENTRO c
            LEFT JOIN ESTUDIANTE e ON c.CODIGO = e.CENTRO_CODIGO
            WHERE c.SEDE_CODIGO IS NULL
            GROUP BY c.CODIGO
            ORDER BY total_estudiantes DESC;

        v_mejor_sede VARCHAR2(50);
        v_max_plazas NUMBER;
    BEGIN
        -- Auto-asignar centros que son institutos
        UPDATE CENTRO c
        SET SEDE_CODIGO = (
            SELECT s.CODIGO
            FROM SEDE s
            WHERE UPPER(s.NOMBRE) = UPPER(c.NOMBRE)
              AND UPPER(s.TIPO) = 'INSTITUTO'
        )
        WHERE EXISTS (
            SELECT 1
            FROM SEDE s
            WHERE UPPER(s.NOMBRE) = UPPER(c.NOMBRE)
              AND UPPER(s.TIPO) = 'INSTITUTO'
        );

        -- Recorrer centros pendientes
        FOR v_centro IN c_centros_pendientes LOOP
            SELECT CODIGO, plazas_libres INTO v_mejor_sede, v_max_plazas
            FROM (
                SELECT CODIGO, PK_ASIGNA.F_PLAZAS(CODIGO) as plazas_libres
                FROM SEDE
                ORDER BY plazas_libres DESC
            )
            WHERE ROWNUM = 1;

            IF v_max_plazas >= v_centro.total_estudiantes THEN
                UPDATE CENTRO
                SET SEDE_CODIGO = v_mejor_sede
                WHERE CODIGO = v_centro.CODIGO;
            ELSE
                RAISE e_sin_espacio;
            END IF;
        END LOOP;

        COMMIT;

    EXCEPTION
        WHEN e_sin_espacio THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001,
              'Error: No hay plazas suficientes en ninguna sede.');
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END PR_ASIGNA_SEDE;

END PK_ASIGNA;
/


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
PROMPT SEGUNDA ENTREGA COMPLETADA
PROMPT ========================================
