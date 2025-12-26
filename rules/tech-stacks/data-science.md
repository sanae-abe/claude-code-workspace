# Data Science Development

## Quality Standards

### Code Quality
- **Type Hints**: Type hints required in function signatures
- **Docstrings**: Documentation for functions and classes
- **Linter**: 0 errors with flake8, pylint
- **Formatter**: Unified formatting with black

**Validation commands:**
```bash
black --check .
flake8 . --max-line-length=88
mypy --strict .
```

### Reproducibility
- **Environment Management**: conda/venv + requirements.txt
- **Random Seed Fixing**: Explicit random_state/seed settings
- **Data Versioning**: Use DVC
- **Experiment Management**: MLflow, Weights & Biases

**Reproducibility workflow:**
```python
import random
import numpy as np
import torch

def set_seeds(seed=42):
    """Fix random seeds for all libraries"""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    # sklearn: specify random_state=seed in parameters
```

**Environment freezing:**
```bash
# Snapshot environment
pip freeze > requirements.txt
conda env export > environment.yml
```

### Documentation
- **README**: Environment setup, execution instructions
- **Notebook**: Explanations in markdown cells
- **Results Recording**: Experiment results, parameters, metrics

Quality validation: See `~/.claude/validation/layers/syntax.md`

## Data Security

### Personal Information Protection
- **Anonymization**: Remove/mask personally identifiable information
- **Access Control**: Manage data access permissions
- **Encryption**: Encrypted storage of sensitive data
- **Audit Logging**: Mandatory recording of data access

**PII Detection Patterns:** See `~/.claude/validation/security-patterns.json`

### Credential Management
```python
import os
from dotenv import load_dotenv
import logging

load_dotenv()  # Load from .env

# Required: Validate credentials
DB_PASSWORD = os.getenv('DB_PASSWORD')
if not DB_PASSWORD or len(DB_PASSWORD) < 8:
    raise ValueError("Invalid DB_PASSWORD")

# Required: Audit logging for data access
logging.info(f"Data access: {dataset_name} by {user_id} at {timestamp}")

# ❌ Hardcoding forbidden
# DB_PASSWORD = "secret123"
```

### Dependency Security
```bash
# Vulnerability scanning required
safety check
pip-audit
```

### Model Security
- **Input Validation**: Range checks, type validation
- **Model Versioning**: Track model lineage
- **Adversarial Robustness**: Test against adversarial examples

```python
def validate_model_input(data):
    """Validate model input"""
    if not isinstance(data, pd.DataFrame):
        raise TypeError("Input must be DataFrame")

    required_columns = ['feature1', 'feature2']
    if not all(col in data.columns for col in required_columns):
        raise ValueError(f"Missing required columns: {required_columns}")

    # Range checks
    if (data['feature1'] < 0).any() or (data['feature1'] > 100).any():
        raise ValueError("feature1 out of range [0, 100]")

    return True
```

## Data Processing

### Tool Selection Decision Tree

```markdown
Tool selection by data size:
  IF data_size < 1GB:
      → pandas (fastest implementation, rich API)

  ELIF 1GB <= data_size < 100GB:
      → dask (pandas-compatible API, parallel processing)
      workers = CPU_cores - 1 (CPU-bound)
      workers = CPU_cores * 2-4 (I/O-bound)

  ELIF data_size >= 100GB OR need_streaming:
      → dask + partitioning (streaming processing)

  IF speed_critical AND data_fits_memory AND NOT ml_pipeline:
      → polars (Rust implementation, 5-10x faster than pandas)
      Warning: Limited ML library integration (scikit-learn, PyTorch)
      Use when: Data transformation heavy, minimal visualization needs
```

### Memory Optimization
```python
import pandas as pd
from memory_profiler import profile

# Memory-efficient loading
df = pd.read_csv('large_file.csv',
    dtype={'col1': 'int32'},  # int64→int32 reduces 50%
    usecols=['col1', 'col2'],  # Only necessary columns
    chunksize=10000  # Chunk reading
)

# Memory profiling required
@profile
def process_data(df):
    result = df.groupby('category').agg({'value': 'mean'})
    return result

# Check memory usage
print(df.memory_usage(deep=True).sum() / 1024**2, "MB")
```

### Parallel Processing
```python
import dask.dataframe as dd
from dask.distributed import Client

# Dask parallel processing
df = dd.read_csv('100gb_file.csv')

# Determine number of workers
import multiprocessing
n_workers = multiprocessing.cpu_count() - 1  # CPU-bound
# n_workers = multiprocessing.cpu_count() * 2  # I/O-bound

client = Client(n_workers=n_workers)

# pandas-compatible API
result = df.groupby('category')['value'].mean().compute()
```

## Data Validation

### Schema Validation
```python
import pandera as pa

# Define schema
schema = pa.DataFrameSchema({
    "age": pa.Column(int, pa.Check.between(0, 120)),
    "income": pa.Column(float, pa.Check.greater_than(0)),
    "category": pa.Column(str, pa.Check.isin(['A', 'B', 'C']))
})

# Execute validation
try:
    validated_df = schema.validate(df)
except pa.errors.SchemaError as e:
    print(f"Validation failed: {e}")
```

### Data Quality Checks
```python
def check_data_quality(df):
    """Data quality checklist"""
    report = {}

    # Missing value check
    report['missing'] = df.isnull().sum()

    # Duplicate check
    report['duplicates'] = df.duplicated().sum()

    # Outlier check (IQR method)
    Q1 = df.quantile(0.25)
    Q3 = df.quantile(0.75)
    IQR = Q3 - Q1
    outliers = ((df < (Q1 - 1.5 * IQR)) | (df > (Q3 + 1.5 * IQR))).sum()
    report['outliers'] = outliers

    return report
```

## Practical Patterns

### Data Preprocessing Decision Table

| Situation | Solution Pattern | Key Commands/Libraries | Benefits |
|-----------|------------------|------------------------|----------|
| Scattered preprocessing code | sklearn.Pipeline | `ColumnTransformer` + `Pipeline` | Improved reproducibility, readability |
| Lost experiment results | MLflow experiment management | `mlflow.start_run()` context | All experiments comparable |
| Memory error with 100GB+ | Dask parallel processing | `dd.read_csv()` + `.compute()` | Memory efficiency, 4x speedup |

### Preprocessing Method Selection

**Missing value handling:**
```markdown
IF missing_rate < 5%:
    → dropna() (deletion)
ELIF feature_important AND missing_rate < 30%:
    → Imputation (mean/median/KNN)
ELSE:
    → Feature deletion
```

**Scaling selection:**
```markdown
IF outliers_present:
    → RobustScaler (IQR-based, robust to outliers)
ELIF need_bounded_range:
    → MinMaxScaler ([0, 1] normalization)
ELSE:
    → StandardScaler (mean=0, variance=1)
```

### Model Evaluation Metrics Selection

**Classification problems:**
```markdown
IF imbalanced_classes:
    → F1-score, ROC-AUC, PR-AUC
ELIF cost_asymmetric (FP vs FN):
    → Individual Precision/Recall evaluation, Custom cost matrix
ELIF interpretability_required:
    → Precision, Recall (individually explainable)
ELSE:
    → Accuracy
```

**Regression problems:**
```markdown
IF outliers_sensitive:
    → MAE (less affected by outliers)
ELIF need_percentage_error:
    → MAPE (relative error)
ELSE:
    → RMSE (penalizes large errors)

Required: R² (explained variance)
```

**Cross-validation:**
```markdown
IF time_series:
    → TimeSeriesSplit (preserve temporal order)
ELIF imbalanced_classes:
    → StratifiedKFold (preserve class ratios)
ELIF small_dataset (n < 100):
    → LeaveOneOut (maximize data utilization)
ELSE:
    → KFold (k=5, standard)
```

## Feature Engineering

### Categorical Encoding Selection

```markdown
IF cardinality < 10:
    → One-Hot Encoding
    Implementation: pd.get_dummies() or OneHotEncoder()
    Reason: Creates interpretable binary features

ELIF cardinality >= 10 AND target_available:
    → Target Encoding
    Implementation: category_encoders.TargetEncoder()
    Reason: Reduces dimensionality, captures target relationship
    Warning: Risk of overfitting, use with CV

ELIF cardinality >= 50:
    → Hash Encoding
    Implementation: category_encoders.HashingEncoder()
    Reason: Fixed dimensionality regardless of cardinality

ELIF embedding_models (Neural Networks):
    → Embedding Layer
    Implementation: tf.keras.layers.Embedding()
    Reason: Learns optimal representation
```

### Feature Selection Strategy

```markdown
IF high_dimensionality (features > 100):

    IF model == tree_based:
        → Feature Importance from model
        Implementation: model.feature_importances_
        Threshold: Keep top 80% cumulative importance

    ELIF need_interpretability:
        → RFE (Recursive Feature Elimination)
        Implementation: sklearn.feature_selection.RFE()
        Strategy: Start with all features, remove weakest iteratively

    ELIF want_automatic_regularization:
        → LASSO (L1 Regularization)
        Implementation: LassoCV() for automatic alpha selection
        Benefit: Feature selection + model training in one step

    ELIF statistical_approach:
        → Univariate Selection
        Implementation: SelectKBest() with f_classif/f_regression
        Fast: Good for initial screening

ELIF domain_knowledge_available:
    → Manual Feature Engineering
    - Interaction terms: feature1 * feature2
    - Polynomial features: PolynomialFeatures()
    - Domain-specific transformations
```

### Dimensionality Reduction

```markdown
IF need_linear_projection:
    → PCA (Principal Component Analysis)
    Use when: Features are correlated
    Keep: Components explaining 95% variance

ELIF need_nonlinear_projection:
    → t-SNE / UMAP
    Use when: Visualization (2D/3D)
    Warning: Not for model input (slow, non-deterministic)

ELIF text_data OR sparse_features:
    → TruncatedSVD
    Use when: Sparse matrices (TF-IDF, one-hot)
    Faster than PCA for sparse data
```

**Feature engineering code example:**
```python
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.feature_selection import SelectKBest, f_classif
from sklearn.decomposition import PCA

# Categorical encoding decision
def encode_categorical(df, column, cardinality_threshold=10):
    cardinality = df[column].nunique()

    if cardinality < cardinality_threshold:
        # One-hot encoding
        return pd.get_dummies(df, columns=[column])
    else:
        # Target encoding (requires target variable)
        from category_encoders import TargetEncoder
        encoder = TargetEncoder(cols=[column])
        return encoder.fit_transform(df[column], df['target'])

# Feature selection decision
def select_features(X, y, n_features_threshold=100):
    if X.shape[1] > n_features_threshold:
        # Use SelectKBest for high-dimensional data
        selector = SelectKBest(f_classif, k=min(50, X.shape[1]//2))
        X_selected = selector.fit_transform(X, y)
        return X_selected, selector
    return X, None
```

## Hyperparameter Tuning

### Tuning Strategy Selection

```markdown
IF search_space_small (< 20 combinations):
    → GridSearchCV
    Method: Exhaustive search
    Use when: Few hyperparameters, discrete values
    Example: n_estimators=[50,100,150], max_depth=[3,5,7]

ELIF search_space_large AND budget_limited:
    → RandomizedSearchCV
    Method: Random sampling
    Use when: Many hyperparameters, continuous distributions
    Benefit: 10-20% of Grid Search time, 90% performance
    Example: 100 iterations instead of 1000+ combinations

ELIF need_optimal_performance AND computational_budget:
    → Bayesian Optimization
    Tools: Optuna, Hyperopt, scikit-optimize
    Method: Guided search using probabilistic model
    Use when: Expensive model training (DL, large datasets)
    Benefit: Finds optimum faster than random search

ELIF deep_learning_model:
    → Learning Rate Finder + Early Stopping
    Method: Cyclical learning rate or lr_find()
    Tools: PyTorch Lightning, Keras callbacks
    Combine with: ReduceLROnPlateau, EarlyStopping

ELIF tree_based_models:
    → TPE (Tree-structured Parzen Estimator)
    Tools: Optuna with TPE sampler
    Reason: More efficient for tree-based hyperparameters
```

### Search Space Definition

**Good practices:**
```python
# Grid Search - discrete values
param_grid = {
    'n_estimators': [50, 100, 200],
    'max_depth': [3, 5, 7, None],
    'min_samples_split': [2, 5, 10]
}

# Random Search - distributions
from scipy.stats import randint, uniform
param_distributions = {
    'n_estimators': randint(50, 500),
    'max_depth': randint(3, 20),
    'learning_rate': uniform(0.01, 0.3)
}

# Bayesian Optimization (Optuna)
def objective(trial):
    params = {
        'n_estimators': trial.suggest_int('n_estimators', 50, 500),
        'max_depth': trial.suggest_int('max_depth', 3, 20),
        'learning_rate': trial.suggest_float('learning_rate', 0.01, 0.3, log=True)
    }
    # Train and return validation score
    return score
```

### Computational Budget Management

```markdown
IF small_dataset (< 10K rows):
    → Grid Search acceptable
    CV folds: 5-10

ELIF medium_dataset (10K-1M rows):
    → Random Search or Bayesian Optimization
    CV folds: 3-5
    Iterations: 50-100

ELIF large_dataset (> 1M rows):
    → Single validation set + Bayesian Optimization
    CV: Too expensive, use holdout validation
    Early stopping: Mandatory

ELIF very_expensive_model (GPU hours):
    → Coarse-to-fine search
    Step 1: Broad random search (10-20 trials)
    Step 2: Fine grid search around best region
```

**Hyperparameter tuning example:**
```python
from sklearn.model_selection import RandomizedSearchCV
from scipy.stats import randint, uniform
import optuna

# Decision: Use Randomized Search for medium dataset
if dataset_size > 10000 and dataset_size < 1000000:
    param_dist = {
        'n_estimators': randint(50, 500),
        'max_depth': randint(3, 20),
        'min_samples_split': randint(2, 20)
    }

    search = RandomizedSearchCV(
        model,
        param_distributions=param_dist,
        n_iter=100,  # 100 random combinations
        cv=5,
        n_jobs=-1,
        verbose=1
    )
    search.fit(X_train, y_train)
    best_model = search.best_estimator_

# For expensive models: Optuna with pruning
elif model_training_time > 60:  # seconds
    def objective(trial):
        params = {
            'n_estimators': trial.suggest_int('n_estimators', 50, 500),
            'max_depth': trial.suggest_int('max_depth', 3, 20)
        }
        model = RandomForestClassifier(**params)

        # Pruning: Stop unpromising trials early
        for fold in range(5):
            score = cross_val_score(model, X_train, y_train, cv=5).mean()
            trial.report(score, fold)
            if trial.should_prune():
                raise optuna.TrialPruned()

        return score

    study = optuna.create_study(direction='maximize')
    study.optimize(objective, n_trials=50)
    best_params = study.best_params
```

## Model Deployment

### Model Serialization

```python
import joblib
import pickle

# joblib (recommended: scikit-learn)
joblib.dump(model, 'model.pkl')
model = joblib.load('model.pkl')

# ONNX (recommended: production, language-agnostic)
from skl2onnx import convert_sklearn
onnx_model = convert_sklearn(model, initial_types=[('input', FloatTensorType([None, n_features]))])
```

**Selection criteria:**
```markdown
IF production AND language_agnostic:
    → ONNX (usable from C++/Java etc.)
ELIF pytorch_model:
    → torch.save() / TorchScript
ELIF tensorflow_model:
    → SavedModel format
ELSE:
    → joblib (Python environment)
```

### API Serving

```python
from fastapi import FastAPI
import pandas as pd

app = FastAPI()

# Load model
model = joblib.load('model.pkl')

@app.post("/predict")
async def predict(data: dict):
    # Input validation
    df = pd.DataFrame([data])
    validate_model_input(df)

    # Prediction
    prediction = model.predict(df)
    return {"prediction": prediction.tolist()}
```

**Inference type selection:**
```markdown
IF realtime_requirement (< 100ms):
    → REST API (FastAPI/Flask) + caching
ELIF batch_processing:
    → Apache Airflow + Dask
ELIF high_throughput:
    → gRPC + model parallelization
```

### Production ML Serving Frameworks

**Framework selection for production deployment:**

```markdown
IF small_team OR rapid_prototyping:
    → FastAPI + joblib
    Pros: Simple, flexible, full control
    Cons: Manual batching, scaling, monitoring
    Use when: MVP, small scale (< 100 req/sec)

ELIF production_scale AND need_features:
    → BentoML
    Features: Adaptive batching, A/B testing, autoscaling
    Performance: 1500 req/sec (87.5% faster than Flask)
    Memory: 450MB vs 650MB (Flask), 2.5s cold start
    Integration: Kubernetes-ready, CI/CD friendly
    Use when: Production ML services, team scaling

ELIF gpu_intensive OR multi_framework:
    → NVIDIA Triton Server
    Pros: Multi-framework (TF, PyTorch, ONNX), GPU optimized
    Cons: Complex setup, overkill for CPU-only
    Use when: GPU workloads, high throughput (10K+ req/sec)

ELIF tensorflow_ecosystem:
    → TensorFlow Serving
    Pros: Native TF integration, battle-tested
    Cons: TensorFlow-only
```

**BentoML example:**
```python
import bentoml
from bentoml.io import JSON, NumpyNdarray
import pandas as pd

# Save model
bentoml.sklearn.save_model("my_model", model)

# Create service
@bentoml.service(
    resources={"cpu": "2"},
    traffic={"timeout": 10},
)
class MyModelService:
    model = bentoml.sklearn.get("my_model:latest")

    @bentoml.api(
        input=JSON(),
        output=JSON(),
        route="/predict"
    )
    async def predict(self, input_data: dict) -> dict:
        # Automatic batching (adaptive)
        df = pd.DataFrame([input_data])
        prediction = await self.model.async_predict(df)
        return {"prediction": prediction.tolist()}

# Deploy with:
# bentoml serve service:MyModelService
# bentoml containerize service:MyModelService  # Docker image
# bentoml deploy service:MyModelService --cloud  # Cloud deployment
```

**Production deployment best practices:**
```markdown
Optimization:
  - ONNX quantization: INT8 reduces memory 50%, 3x faster inference
  - Response caching (Redis): 40% compute reduction for repeated queries
  - Adaptive batching: BentoML automatic, improves GPU utilization

Monitoring:
  - OpenTelemetry: Distributed tracing for microservices
  - Prometheus metrics: Request latency, throughput, error rates
  - A/B testing: Gradual rollout (10% traffic to v2, then scale)

Scaling:
  - Kubernetes HPA: Auto-scale pods based on CPU/memory
  - Linear scaling: 10K req/sec with pod replication
  - Load balancer: 2% overhead for inter-pod communication
```

### Model Monitoring

```python
def detect_data_drift(reference_data, current_data, threshold=0.05):
    """Data drift detection (Kolmogorov-Smirnov test)"""
    from scipy.stats import ks_2samp

    for column in reference_data.columns:
        statistic, pvalue = ks_2samp(
            reference_data[column],
            current_data[column]
        )
        if pvalue < threshold:
            print(f"Drift detected in {column}: p={pvalue}")
```

## Tech Stack Selection

```markdown
Language selection decision tree:

IF task == "ML/DL" OR task == "data_analysis":
    → Python
    Reason: scikit-learn, pandas, TensorFlow, PyTorch
    Note: Performance (GIL limitation)

ELIF task == "statistical_analysis" AND team == "academic":
    → R
    Reason: tidyverse, ggplot2, rich statistical packages
    Note: ML libraries inferior to Python

ELIF task == "high_performance_computing":
    → Julia
    Reason: Python-like ease of writing, C-like speed
    Note: Ecosystem maturity

ELSE:
    → Python (default)
```

## Complete ML Workflow

```markdown
1. Problem Definition
   - Clarify business objectives
   - Define success metrics
   - Set baseline

2. Data Collection & Validation
   - Identify data sources
   - Schema validation (Pandera)
   - Data quality checks

3. EDA (Exploratory Data Analysis)
   - Check statistics
   - Visualization (matplotlib/seaborn/plotly)
   - Hypothesis generation

4. Feature Engineering
   - Feature creation
   - Feature selection (RFE/LASSO/TreeBased)
   - Feature importance analysis

5. Model Training
   - Build baseline
   - Hyperparameter tuning
   - Cross-validation

6. Model Evaluation
   - Metrics evaluation
   - Statistical significance testing
   - Alignment with business metrics

7. Model Deployment
   - Model serialization
   - API construction (FastAPI)
   - Monitoring setup

8. Operations & Monitoring
   - Data drift detection
   - Model performance monitoring
   - Retraining trigger setup
```

## AutoML Utilization Criteria

```markdown
AutoML recommended:
  IF need_baseline_quickly (< 1 hour):
      → AutoGluon, PyCaret
  ELIF team_lacks_domain_expertise:
      → H2O AutoML
  ELIF standard_tabular_data:
      → AutoGluon

Manual tuning recommended:
  IF novel_problem OR custom_architecture:
      → Manual implementation
  ELIF performance_critical:
      → Manual optimization
  ELIF interpretability_required:
      → Manual model selection
```

## Reference: External Documentation

Use WebFetch tool when external documentation is needed:
- pandas official: https://pandas.pydata.org/
- scikit-learn official: https://scikit-learn.org/
- MLflow official: https://mlflow.org/
