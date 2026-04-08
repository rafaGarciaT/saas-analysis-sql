# saas-analysis-sql
This project will model a database related to a SaaS writing platform, and then answer business questions with queries and analyses.
The complete description of the software is stored in _docs/software_description.md_. Other documents related to the choices behind the build database will also be stored in _/docs_.

## Goals
The project will aim to answer the following question as its main goal.

"By adding AI related tools, the existing flat subscription rate the SaaS employs, becomes obsolete. How should the new subscription model be to fit the new features?"

- Design a normalized relational database for a SaaS writing platform
- Model subscription lifecycle and billing systems
- Implement analytical queeries for key metrics
- Simulate real-world data workflows
- Use only SQL, with the PostgreSQL dialect



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
