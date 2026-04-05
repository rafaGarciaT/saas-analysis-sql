# saas-analysis-sql
This project will model a database related to a SaaS writing platform, and then answer business questions with queries and analyses.
The complete description of the software is stored in _docs/software_description.md_. Other documents related to the choices behind the build database will also be stored in _/docs_.

## Goals
- Design a normalized relational database for a SaaS writing platform
- Model subscription lifecycle and billing systems
- Implement analytical queeries for key metrics
- Simulate real-world data workflows
- Use only SQL, with the PostgreSQL dialect

## Other Information About The Future Database
- SQL Dialect: PostgreSQL

## Folder Structure To Be Implemented
```
saas-sql-project/
│
├── README.md
│
├── docs/                   # Documentation. Diagrams
│
├── schema/
│
├── seed/
│
├── transformations/
│   ├── staging/
│   │
│   └── intermediate/
│
├── analytics/
│   ├── revenue/
│   │
│   ├── churn/
│   │
│   ├── retention/
│   │
│   └── usage/
│
└── tests/                  # For data quality checks
```
