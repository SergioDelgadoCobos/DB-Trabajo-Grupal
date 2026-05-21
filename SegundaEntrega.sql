-- Usuario SYS
GRANT CREATE SEQUENCE TO PAU;

-- Usuario PAU (a partir de ahora se ejecuta todo con este usuario)
-- Asignar todos los indices creados junto con el diagrama ER al tablespace TS_INDICES
ALTER INDEX ANE_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX ASISTENCIA_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX AULA_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX CENTRO_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX ESTUDIANTE_MATERIA_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX ESTUDIANTE_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX EXAMEN_MATERIA_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX EXAMEN_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX EXAMEN_VOCAL_VIGILANTES_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX MATERIA_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX SEDE_PK REBUILD TABLESPACE TS_INDICES;
ALTER INDEX SEDE_UQ_VOCAL_RESP REBUILD TABLESPACE TS_INDICES;
ALTER INDEX SEDE_UQ_VOCAL_SEC REBUILD TABLESPACE TS_INDICES;
ALTER INDEX VOCAL_PK REBUILD TABLESPACE TS_INDICES;

-- Comprobar que los indices han sido reasignados correctamente
SELECT INDEX_NAME, TABLESPACE_NAME FROM USER_INDEXES;

-- Nuevos índices
CREATE INDEX IDX_ESTUDIANTE_APELLIDOS_UP ON ESTUDIANTE (UPPER(Apellidos)) TABLESPACE TS_INDICES;
CREATE INDEX IDX_ESTUDIANTE_CORREO ON ESTUDIANTE (Correo) TABLESPACE TS_INDICES;
CREATE BITMAP INDEX IDX_ESTUDIANTE_CENTRO_BM ON ESTUDIANTE (Centro_Codigo) TABLESPACE TS_INDICES;

-- Comprobar los índices
SELECT table_name, index_name, index_type, tablespace_name FROM user_indexes WHERE table_name = 'ESTUDIANTE';
SELECT table_name, tablespace_name FROM user_tables WHERE table_name = 'ESTUDIANTE';

-- view materializada
CREATE MATERIALIZED VIEW VM_ESTUDIANTES
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
START WITH TRUNC(SYSDATE + 1)
NEXT TRUNC(SYSDATE + 1)
AS
SELECT * FROM V_ESTUDIANTES;

CREATE PUBLIC SYNONYM S_ESTUDIANTES FOR VM_ESTUDIANTES;
SELECT SYNONYM_NAME, TABLE_OWNER, TABLE_NAME
FROM ALL_SYNONYMS
WHERE SYNONYM_NAME = 'S_ESTUDIANTES';

ALTER TABLE CENTRO MODIFY (Sede_Codigo NULL);

-- secuencia SEQ_CENTROS
CREATE SEQUENCE SEQ_CENTROS;

-- trigger tr_centros
CREATE OR REPLACE TRIGGER tr_centros
BEFORE INSERT ON CENTRO 
FOR EACH ROW
BEGIN
    IF :new.Codigo IS NULL THEN
        :new.Codigo := TO_CHAR(SEQ_CENTROS.NEXTVAL);
    END IF;
END tr_centros;
/

-- Prueba de inserción
INSERT INTO CENTRO (Nombre) VALUES ('Ejemplo');
SELECT * FROM CENTRO;
ROLLBACK;

-- Insertamos los centros reales desde la vista V_ESTUDIANTES
INSERT INTO CENTRO (Nombre) 
SELECT DISTINCT centro FROM v_estudiantes;

-- Comprobamos
SELECT * FROM CENTRO;
COMMIT;

-- Insertamos los estudiantes reales desde la vista V_ESTUDIANTES
INSERT INTO ESTUDIANTE (DNI, Nombre, Apellidos, Telefono, Correo, Centro_Codigo)
SELECT 
    v.dni, 
    v.nombre, 
    v.apellidos, 
    v.telefono, 
    v.correo, 
    c.Codigo
FROM V_ESTUDIANTES v
JOIN CENTRO c ON v.centro = c.Nombre;

-- Creacion del paquete junto con la declaracion de sus funciones
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
        SELECT NVL(SUM(CAPACIDAD_EXAMEN), 0)
        INTO v_capacidad
        FROM AULA
        WHERE SEDE_CODIGO = PSEDE;

        SELECT NVL(COUNT(*), 0)
        INTO v_estudiantes
        FROM ESTUDIANTE e
        JOIN CENTRO c ON e.CENTRO_CODIGO = c.CODIGO
        WHERE c.SEDE_CODIGO = PSEDE;

        RETURN v_capacidad - v_estudiantes;
    END F_PLAZAS;

    PROCEDURE PR_ASIGNA_SEDE AS
        -- Declaramos una excepcion personalizada para cuando no haya espacio
        e_sin_espacio EXCEPTION;
        
        -- Cursor para obtener los centros sin sede, ordenados por numero de estudiantes (de mayor a menor)
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
        -- Auto-asignar los centros que son Sede (tipo INSTITUTO)
        -- Usamos UPPER para no tener problemas con las mayusculas/minusculas
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

        -- Recorrer el resto de centros pendientes
        FOR v_centro IN c_centros_pendientes LOOP
            
            -- Buscar la sede que tenga mas plazas libres EN ESTE MOMENTO
            -- Usamos ROWNUM = 1 para quedarnos solo con la que mas tiene
            SELECT CODIGO, plazas_libres INTO v_mejor_sede, v_max_plazas
            FROM (
                SELECT CODIGO, PK_ASIGNA.F_PLAZAS(CODIGO) as plazas_libres
                FROM SEDE
                ORDER BY plazas_libres DESC
            )
            WHERE ROWNUM = 1;

            -- Comprobar si el centro cabe entero en la mejor sede
            IF v_max_plazas >= v_centro.total_estudiantes THEN
                -- Si hay espacio, asignamos la sede al centro
                UPDATE CENTRO
                SET SEDE_CODIGO = v_mejor_sede
                WHERE CODIGO = v_centro.CODIGO;
            ELSE
                -- Si no hay espacio, elevamos la excepcion para no dividir el centro
                RAISE e_sin_espacio;
            END IF;

        END LOOP;

        -- Si todo el proceso termina bien, confirmamos los cambios
        COMMIT;

    EXCEPTION
        WHEN e_sin_espacio THEN
            -- Deshacemos todo lo de este procedimiento y mostramos el error
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20001, 'Error: No hay plazas suficientes en ninguna sede para albergar a todo un centro sin dividirlo.');
    END PR_ASIGNA_SEDE;

END PK_ASIGNA;
/
