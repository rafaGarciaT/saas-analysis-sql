# Software Description
As described in the .md, the software this database project is related to, is a theoretical writing platform with the main goal being to make the writing process easier for anyone.

The platform targets individual writers and professional users who require revision tools and structured feedback, by creating an environment that provides both of those purposes.

The software, so far, achieved its goal with the following features.

(Across this document, the features will be referenced by their respective numbers in this ordered list)

1. A setup tab to define what the user is writing, and what are their goals with their writing. This is used to adapt all other functions
2. Spelling and grammar checker
3. Grading system that tells the user how close their text is at achieving their goal. Each grading segment has its own list of suggestions for improvement

As for the pricing. That was, up until that point, a very straightforward issue to the team. The subscription model worked like the following:
**Pro Plan Price**:
    - Monthly: $14
    - Yearly: $130

| List of features          | Free Plan                    | Pro Plan |
| :-------:                 | :-------:                    | :------: |
| Spell checker             | Included                     | Included |
| Grading/Suggestion system | Limited (5 suggestions daily)| Included |
| Setup tab                 | Not Included                 | Included |
| Ad-free                   | Not Included                 | Included |

However, the team was unsatisfied with the feedback portion of their software. It was decided that implementing an AI chat as an optional tool was ideal for strenghtening the feedback features of the software. The following was added.

4. AI tools for an "outside perspective" feedback
5. AI tools for suggesting general directions the user can go with their text.

But now there was a problem. It isn't clear if these new features would fit the existing subscription model. Not all users would want AI tools. And the usage of AI introduces a lot of uncertainty in the costs of the software.

The objective of this project, is to analyse the existing subscription tiers and come up with a new model that balances profitability, feature accessibility and user retention.

How should the new subscription model be like? How should the AI tools be set up to ensure profitability, while also not sacrificing the goals the software should meet? This is the purpose of this analysis.

The following, are assumptions we will be making for the project.

## Operational Cost Assumptions
These are the fixed monthly operational costs of the platform, independent of user activity.

- Infrastructure (servers, storage, hosting): $5,000/month
- Salaries and operations: $20,000/month

A total of $25,000/month.

The following are variable costs that scale per user. These are non-AI related costs.

- Storage and basic processing: $0.10 per user per month

## User Base Assumptions
Let's say that, currently, the platform is assumed to have:

- 10,000 users

From which...

- 80% (8,000 users) of them are in the free plan
- 15% (1,500 users) of them are monthly payers of the pro plan
- 5% (500 users) of them are yearly payers of the pro plan

Users can also be divided into behavior groups:

- Light users (50%)
  - Small documents
  - Low AI usage

- Moderate users (35%)
  - Regular feature usage
  - Moderate AI usage

- Heavy users (15%)
  - Most likely to be a paid user
  - Large documents
  - High AI usage

However, these groups will be derived from usage data rather than explicitly stored.

## AI Cost Assumptions
Let's define a base AI costs for the purpose of this project. We'll approximate the costs using:
- Each AI request has a base cost
- Additional costs scales with context length

The cost per request can be modeled as:
```
cost = base_cost + (context_length x cost_per_unit)
```

Values:   
- base_cost per request: $0.01
- cost_per_unit of context: $0.00001 per character
- context_length: number of characters in the request

To simplify, we can group different types of requests together:
- Small request (≤ 1,000 chars): $0.01
- Medium request (1,000–10,000 chars): $0.03
- Large request (> 10,000 chars): $0.08

## Ad Income Assumptions
We should also define how much income we get from advertisement, since it is also a source of income.
- Average impression per user per month: 50
- CPM (cost per thousand impressions): $4

Model:
```
Monthly_revenue_per_user = (50 / 1000) x $4
Monthly_revenue_per_user = $0.2
```

However, we should also assume that, from the 8,000 users that are in the free plan, 35% uses ad-blockers (which is close to the global percentage of internet users that use ad-blockers)

## Data Model Implications
## Data Model Implications

Considering the assumptions above, the database must support tracking of:

### Core Entities

- Users and accounts
- Subscription plans and pricing
- Subscription lifecycle (start, end, upgrades, cancellations)

---

### Revenue Tracking

To model revenue, the database must include:

- Subscription payments (monthly and yearly)
- Plan pricing history (optional but strong)
- Ad revenue attribution (per free user)

---

### AI Usage Tracking

To support cost modeling:

- AI request events
- Context length per request
- Feature type (feedback, suggestions, etc.)
- Timestamp of each request

---

### User Segmentation

To enable behavioral analysis:

- User activity classification (light, moderate, heavy)
- Derived from usage patterns (not hardcoded)

---

### Cost Modeling

To compute total costs:

- AI cost per request (derived from usage)
- Per-user baseline cost (constant)
- Aggregation of costs at user and plan level

---

### Analytical Capabilities

The model should support queries for:

- Revenue per user and per plan
- Cost per user (AI + baseline)
- Profitability per segment
- Churn and retention by plan
- Usage distribution across users
