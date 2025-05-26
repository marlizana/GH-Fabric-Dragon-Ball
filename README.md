# Dragon Ball Analytics Platform

## Visión general  

El proyecto "Dragon Ball Analytics Platform" es una demostración de una solución completa de analítica moderna utilizando Microsoft Fabric. Permite el seguimiento, análisis y visualización de datos relacionados con personajes del universo Dragon Ball, proporcionando insights valiosos sobre sus características, habilidades y relaciones.

## Valor de negocio

Este proyecto demuestra cómo implementar una plataforma analítica end-to-end con CI/CD automatizado, garantizando:

- **Calidad de datos consistente**: Validación automática de modelos semánticos y reportes
- **Gobernanza de datos**: Implementación de estándares de nomenclatura y buenas prácticas
- **Desarrollo ágil**: Integración continua y despliegue continuo para acelerar el time-to-market
- **Escalabilidad**: Arquitectura preparada para crecer con el negocio

## Arquitectura

La solución utiliza una arquitectura moderna de lakehouse con diferentes capas:

1. **Capa Bronze**: Ingesta y almacenamiento de datos crudos de Dragon Ball
2. **Capa Semántica**: Modelado de datos para análisis
3. **Capa de Visualización**: Informes y dashboards para consumo final

## Componentes principales

### Ingesta y procesamiento de datos
- **Notebook (NB_BRONZE_DragonBall)**: Extrae datos de personajes desde Kaggle y realiza transformaciones iniciales
- **Lakehouse (LH_FT_BRONZE_DragonBall)**: Almacena los datos en formato Delta para optimizar consultas

### Modelado de datos
- **Modelo Semántico (DragonBall.SemanticModel)**: Define relaciones entre entidades, métricas y KPIs para análisis avanzados
- Incluye tablas de personajes con atributos como poder, velocidad, técnicas especiales y afiliaciones

### Visualización
- **Informes (DragonBall.Report)**: Dashboards interactivos que permiten:
  - Comparar habilidades entre personajes
  - Filtrar por razas o afiliaciones
  - Analizar características detalladas de cada personaje

## Automatización y CI/CD

El proyecto implementa un completo pipeline de CI/CD para garantizar la calidad y consistencia:

### Pipeline Azure DevOps (ado-pipe-build.yaml)
- **Validación de modelos semánticos**: Verifica buenas prácticas en modelos de datos
- **Validación de informes**: Asegura que los informes siguen estándares de diseño y rendimiento
- **Verificación de nomenclatura**: Garantiza que todos los componentes sigan las convenciones establecidas

### Scripts de automatización
- `bpa-semanticmodel.ps1`: Análisis de buenas prácticas para modelos semánticos
- `bpa-report.ps1`: Análisis de buenas prácticas para informes
- `naming_conv_test.ps1`: Validación de convenciones de nomenclatura

## Ventajas para el negocio

- **Insights accionables**: Comprensión profunda de las características de los personajes de Dragon Ball
- **Consistencia de datos**: Garantía de calidad mediante validación automatizada
- **Desarrollo colaborativo**: Flujos de trabajo que permiten contribuciones de múltiples equipos
- **Escalabilidad**: Arquitectura preparada para incorporar nuevos datos o casos de uso

## Cómo empezar

1. Clone este repositorio
2. Configure su entorno Microsoft Fabric
3. Ejecute el notebook para cargar datos iniciales
4. Explore los informes de análisis de personajes
5. Utilice el pipeline de Azure DevOps para validar cambios

## Requisitos técnicos

- Microsoft Fabric (Power BI, Synapse, etc.)
- Azure DevOps
- PowerShell 7.0+
- Acceso a fuentes de datos Kaggle

## Contribución

Este proyecto sigue un proceso de contribución basado en pull requests con validación automática de estándares y buenas prácticas para garantizar la calidad del código y los activos analíticos.
