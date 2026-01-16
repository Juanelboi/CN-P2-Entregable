# Proyecto League of Legends - AWS Integration

## Descripción

Este proyecto integra datos de League of Legends con servicios de AWS (Kinesis y Firehose) para procesamiento y análisis de información de jugadores y rankings.

## Requisitos

- Python 3.8+
- `boto3` - SDK de AWS para Python
- `loguru` - Librería para logging

## Instalación

### 1. Clonar el proyecto

```bash
git clone <tu-repositorio>
cd CN-P5
```

### 2. Crear el entorno virtual con `uv`

```bash
# Inicializar el proyecto
uv init

# Instalar dependencias
uv add boto3
uv add loguru

# Crear el entorno virtual
uv venv
```

### 3. Activar el entorno virtual

**Windows (PowerShell):**
```powershell
.venv\Scripts\activate
```

**Windows (CMD):**
```cmd
.venv\Scripts\activate.bat
```

**Linux / macOS:**
```bash
source .venv/bin/activate
```

## Uso

### Configuración de AWS

Antes de ejecutar los scripts, asegúrate de tener configuradas tus credenciales de AWS:

```bash
aws configure
```

### Estructura del Proyecto

- **`kinesis.py`** - Integración con Amazon Kinesis
- **`firehose.py`** - Integración con Amazon Kinesis Data Firehose
- **`lol_ranks_partitioned_*.py`** - Scripts para procesar rankings de LoL
- **`playerslol.json`** - Datos de jugadores
- **`Scripts/`** - Scripts adicionales y conversión de datos CSV a JSON

## Cómo Iniciar

```bash
python scriptInicio.py
```
Para iniciar los diferentes servicios de AWS

Con el entorno virtual iniciado se debe hacer lo siguiente
```bash
py .\kinesis.py
```
Para empezar a enviar los datos

Se recomienda dejar el script anterior durante un par de minutos antes de proceder a iniciar este
```bash
python scriptTrabajo.py
```
Este script inicia los crawlers y los ETL jobs ademas de hacer dos queries basicas de Athena 
---
