   # Fabric Dragon Ball: Calidad y Gobernanza Automatizada con GitHub Actions


## Visión General

Bienvenido al proyecto "Fabric Dragon Ball", una demostración de cómo implementar una plataforma analítica robusta en Microsoft Fabric con un fuerte enfoque en la calidad y gobernanza automatizada utilizando GitHub Actions.

Este proyecto utiliza datos del universo Dragon Ball para ilustrar una solución end-to-end que garantiza:

-   **Calidad en el desarrollo:** Mediante validaciones automáticas integradas en el flujo de trabajo de GitHub.
-   **Gobernanza efectiva:** Aplicando estándares y buenas prácticas de forma consistente.
-   **Desarrollo ágil:** A través de la Integración Continua (CI) y el Despliegue Continuo (CD) facilitados por GitHub Actions.

## Valor de Negocio

Este proyecto demuestra cómo implementar una plataforma analítica moderna con CI/CD automatizado en GitHub, garantizando:

-   **Calidad de datos y artefactos consistente**: Validación automática de modelos semánticos y reportes.
-   **Gobernanza de datos proactiva**: Implementación y verificación automática de estándares de nomenclatura y buenas prácticas.
-   **Desarrollo ágil y eficiente**: Integración continua para acelerar el time-to-market y reducir errores manuales.
-   **Colaboración mejorada**: Flujos de trabajo claros y automatizados para los Pull Requests.

## Arquitectura de la Automatización

La solución se centra en la automatización de la calidad y la gobernanza mediante:

1.  **Scripts de Validación PowerShell**: Herramientas personalizadas para analizar los artefactos de Microsoft Fabric.
2.  **Flujos de Trabajo de GitHub Actions**: Orquestación de la ejecución de los scripts y gestión de los Pull Requests.
3.  **Reglas de Protección de Rama**: Para asegurar la integridad de las ramas principales.

## Componentes Principales de la Automatización

### Scripts de Automatización PowerShell

El corazón de esta estrategia de calidad son cuatro scripts PowerShell que analizan modelos semánticos, reportes, convenciones de nomenclatura y campos no utilizados. Cada script genera informes en formato NUnit XML, listos para ser procesados por el flujo de trabajo de CI/CD.

-   `bpa-semanticmodel.ps1`: Análisis de buenas prácticas para modelos semánticos.
-   `bpa-report.ps1`: Análisis de buenas prácticas para informes.
-   `naming_conv_test.ps1`: Validación de convenciones de nomenclatura.
-   `unused-fields.ps1`: Detección de campos no utilizados en los modelos.

*Para una descripción detallada de cada script y su funcionamiento, consulta nuestro [artículo sobre herramientas de validación](https://medium.com/@akanemar/calidad-nivel-saiyan-automatizando-los-test-de-calidad-y-gobernanza-de-microsoft-fabric-3284b9f06d43).*

### Automatización con GitHub Actions

Este repositorio utiliza GitHub Actions para la Integración Continua.

#### Flujo de Trabajo de CI (`.github/workflows/build.yml`)
Nuestro flujo de trabajo principal, definido en `build.yml`, se activa con Pull Requests a las ramas `main` y `dev`.
Puntos clave:
-   **Ejecución de Validaciones**: Ejecuta los scripts de PowerShell en un entorno Windows.
-   **Gestión de Errores**: `continue-on-error: true` en los pasos de validación asegura que todos los scripts se ejecuten.
-   **Resultados de Pruebas**: Publica los resultados de las pruebas usando `EnricoMi/publish-unit-test-result-action`, visibles en la pestaña "Checks" del Pull Request.
-   **Bloqueo de Merge a `main`**: Si alguna validación falla (basado en el `outcome` del paso) y el Pull Request es hacia `main`, el flujo de trabajo se marca como fallido (`core.setFailed`), impidiendo el merge si las reglas de protección de rama están configuradas adecuadamente.

#### Reglas de Protección de Rama
Hemos configurado reglas de protección para:
-   **Rama `main`**:
    -   Requerir un Pull Request antes de fusionar.
    -   Requerir que las comprobaciones de estado (específicamente el job `FabricValidation` de nuestro workflow) pasen antes de fusionar.
    -   Opcionalmente, requerir aprobaciones.
-   **Rama `dev`**:
    -   Requerir un Pull Request.
    -   Las comprobaciones de estado pueden ser obligatorias o informativas, permitiendo flexibilidad. La acción `EnricoMi/publish-unit-test-result-action` informará de los errores, pero el merge no se bloqueará automáticamente a menos que se configure explícitamente como un "check" requerido.

*Para una guía paso a paso sobre cómo configurar GitHub Actions y las Reglas de Protección de Rama, visita nuestro [artículo sobre Calidad con GitHub Actions y Reglas de Protección](enlace-al-articulo-de-github-actions).* (Asegúrate de reemplazar `enlace-al-articulo-de-github-actions` con el enlace correcto)

## Cómo Empezar

1.  **Clona este repositorio:**
    ```bash
    git clone https://github.com/marlizana/GH-Fabric-Dragon-Ball.git # Reemplaza con la URL de tu repositorio si es diferente
    cd GH-Fabric-Dragon-Ball
    ```
2.  **Configura tu entorno Microsoft Fabric:** Asegúrate de tener un workspace y las capacidades necesarias.
3.  **Explora los artefactos de ejemplo:** Revisa los modelos semánticos y reportes en la carpeta `src/`.
4.  **Realiza un cambio y crea un Pull Request:** Observa cómo se ejecuta el flujo de trabajo de GitHub Actions y cómo se aplican las validaciones.
5.  **Revisa los resultados de las validaciones:** En la pestaña "Checks" de tu Pull Request.

## Requisitos Técnicos

-   Cuenta de GitHub.
-   Microsoft Fabric (para los artefactos de Power BI, modelos semánticos, etc.).
-   PowerShell 7.0+ (para ejecutar los scripts localmente si se desea).


## Más Información en el Blog

Profundiza en los conceptos y configuraciones revisando nuestros artículos:

1.  [Herramientas de Validación (Scripts PowerShell)](https://medium.com/@akanemar/calidad-nivel-saiyan-automatizando-los-test-de-calidad-y-gobernanza-de-microsoft-fabric-3284b9f06d43)
2.  [CI/CD en Azure DevOps: Pipelines y Políticas de Rama](https://medium.com/@akanemar/azure-devops-pipelines-y-pol%C3%ADticas-de-ramas-d7b0da495084) (Referencia para la alternativa en Azure DevOps)
3.  [Calidad con GitHub Actions y Reglas de Protección](enlace-al-articulo-de-github-actions) (¡Asegúrate de actualizar este enlace!)
