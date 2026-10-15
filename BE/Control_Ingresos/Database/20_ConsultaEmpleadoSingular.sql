/*
  Consulta parametrizada de autorizaciones y entrenamientos del empleado.
  La definición permanece en Control Ingresos; la aplicación la ejecuta en
  ConsultaEmpleadosSingular, donde el usuario tiene acceso de solo lectura.
*/
USE [Control_Ingresos_DB];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.OBTENER_CONSULTA_AUTORIZACIONES_EMPLEADO
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(N'
SELECT
    A.Cracha AS CARNET,
    A.Nome AS NOMBRE,
    A.Contrato AS CONTRATO,
    A.Empresa AS EMPRESA,
    A.Cargo AS CARGO,
    A.CNH_Cetegoria AS CATEGORIA_LICENCIA,
    A.CNH_Venc AS VALIDEZ_LICENCIA,
    A.CNH_Codigo AS NUMERO_LICENCIA,
    A.C_STATUS AS ESTADO,
    A.C_DTASO AS VALIDEZ_ASO,
    A.Setor AS AREA,
    A.Gerencia AS GERENCIA,
    A.C_TIPOSANGUINEO AS TIPO_SANGRE
FROM dbo.view_Autorizacoes AS A
WHERE A.Cracha = @CodigoEmpleado;

SELECT
    T.C_DESCRICAO AS ENTRENAMIENTO,
    T.C_DTVALIDADE AS VALIDEZ,
    T.C_DTTREINAMENTO AS FECHA_ENTRENAMIENTO,
    T.C_VRH AS CARGA_HORARIA,
    T.C_TIPO AS TIPO
FROM dbo.view_Autorizacoes_Treinamntos AS T
WHERE T.C_CRACHA = @CodigoEmpleado
ORDER BY T.C_DESCRICAO;' AS NVARCHAR(MAX)) AS CONSULTA_SQL;
END;
GO
