# SqlConverters

# SqlToEcto

SqlToEcto is an Elixir library that converts SQL-like query strings into Ecto queries. It provides a simple way to dynamically generate Ecto queries using familiar SQL syntax.
**Use with caution**

## Features

- Converts SQL SELECT statements to Ecto queries
- Supports WHERE conditions with multiple operators
- Handles ORDER BY clauses with ASC/DESC
- Supports OFFSET for pagination
- Includes GROUP BY support
- Combines conditions with AND/OR operators
- Supports NOT operator for negation

## Installation

Add `sql_to_ecto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sql_to_ecto, "~> 0.1.0"}
  ]
end 
```

## Usage

The main function is `SqlToEcto.to_ecto_query/2`, which takes a SQL-like query string and a schema module.

### Basic Examples

```elixir
iex> sql = "SELECT name WHERE age >= 21 AND city = 'New York'"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", select: [:name]>
```

## Query Syntax   

The general syntax follows this pattern:

```sql
SELECT field1, field2, ...
[WHERE condition1 AND/OR condition2 ...]
[GROUP BY field1, field2, ...]
[ORDER BY field ASC/DESC]
[OFFSET number]
``` 

Note: All field names must correspond to existing fields in your schema.         



###  Simple SELECT with WHERE clause

```elixir
iex> sql = "SELECT name WHERE age >= 21 AND city = 'New York'"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", select: [:name]>
``` 

###  SELECT with ORDER BY and OFFSET

```elixir
iex> sql = "SELECT name ORDER BY age DESC OFFSET 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, order_by: [desc: u.age], offset: ^10, select: [:name]>
```  

###  SELECT with GROUP BY

```elixir
iex> sql = "SELECT city WHERE country = 'USA' GROUP BY city"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.country == ^"USA", group_by: [u.city], select: [:city]>
```  

###  SELECT with NOT operator

```elixir
iex> sql = "SELECT name WHERE NOT age >= 21"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: not(u.age >= ^21), select: [:name]>
```       

###  SELECT with multiple conditions

```elixir
iex> sql = "SELECT name WHERE age >= 21 AND city = 'New York' ORDER BY age DESC OFFSET 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", order_by: [desc: u.age], offset: ^10, select: [:name]>
```

###  SELECT with GROUP BY and ORDER BY

```elixir
iex> sql = "SELECT city WHERE country = 'USA' GROUP BY city ORDER BY city ASC"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.country == ^"USA", group_by: [u.city], order_by: [asc: u.city], select: [:city]>
``` 

###  SELECT with NOT and ORDER BY

```elixir
iex> sql = "SELECT name WHERE NOT age >= 21 ORDER BY age DESC"  



# Multiple conditions with AND

```elixir
iex> sql = "SELECT name WHERE age >= 21 AND city = 'New York' ORDER BY age DESC"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", order_by: [desc: u.age], select: [:name]>
```  

###  Multiple conditions with OR

```elixir
iex> sql = "SELECT name WHERE age >= 21 OR city = 'New York' ORDER BY age DESC"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 or u.city == ^"New York", order_by: [desc: u.age], select: [:name]>
```   

###  Multiple conditions with AND and OR

```elixir
iex> sql = "SELECT name WHERE (age >= 21 AND city = 'New York') OR (age < 21 AND city = 'Los Angeles')"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: (u.age >= ^21 and u.city == ^"New York") or (u.age < ^21 and u.city == ^"Los Angeles"), order_by: [desc: u.age], select: [:name]>
```         

###  SELECT with DISTINCT

```elixir
iex> sql = "SELECT DISTINCT name WHERE age >= 21 AND city = 'New York'"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", distinct: true, select: [:name]>
```    

###  SELECT with LIMIT

```elixir
iex> sql = "SELECT name LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, limit: ^10, select: [:name]>
```    

###  SELECT with OFFSET and LIMIT

```elixir
iex> sql = "SELECT name OFFSET 10 LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, offset: ^10, limit: ^10, select: [:name]>
```     

###  SELECT with DISTINCT and LIMIT

```elixir
iex> sql = "SELECT DISTINCT name LIMIT 10"    
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)       
#Ecto.Query<from u in MyApp.User, distinct: true, limit: ^10, select: [:name]>
```     

### SELECT with DISTINCT and OFFSET and LIMIT

```elixir
iex> sql = "SELECT DISTINCT name OFFSET 10 LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, distinct: true, offset: ^10, limit: ^10, select: [:name]>
```     

### SELECT with ORDER BY and LIMIT

```elixir
iex> sql = "SELECT name ORDER BY age DESC LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, order_by: [desc: u.age], limit: ^10, select: [:name]>
```     

### SELECT with ORDER BY and OFFSET and LIMIT 

```elixir
iex> sql = "SELECT name ORDER BY age DESC OFFSET 10 LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, order_by: [desc: u.age], offset: ^10, limit: ^10, select: [:name]>
```      

### SELECT with GROUP BY and ORDER BY and LIMIT

```elixir
iex> sql = "SELECT city ORDER BY city ASC LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, group_by: [u.city], order_by: [asc: u.city], limit: ^10, select: [:city]>
```      

### SELECT with NOT and ORDER BY and LIMIT

```elixir
iex> sql = "SELECT name WHERE NOT age >= 21 ORDER BY age DESC LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, where: not(u.age >= ^21), order_by: [desc: u.age], limit: ^10, select: [:name]>
```      

### SELECT with DISTINCT and ORDER BY and LIMIT

```elixir
iex> sql = "SELECT DISTINCT name ORDER BY age DESC LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, distinct: true, order_by: [desc: u.age], limit: ^10, select: [:name]>
```     

### SELECT with DISTINCT and ORDER BY and OFFSET and LIMIT

```elixir
iex> sql = "SELECT DISTINCT name ORDER BY age DESC OFFSET 10 LIMIT 10"  
iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
#Ecto.Query<from u in MyApp.User, distinct: true, order_by: [desc: u.age], offset: ^10, limit: ^10, select: [:name]>
```     



# SQL Parser for Flop

A library for converting SQL WHERE clauses to [Flop](https://github.com/woylie/flop) filter parameters in Elixir applications.

## Features

- Parses SQL WHERE conditions into Flop-compatible filter parameters
- Supports:
  - Basic comparison operators (`=`, `!=`, `>`, `<`, `>=`, `<=`, `LIKE`)
  - Logical operators (`AND`, `OR`)
  - `IN` operator
  - `NULL` checks (`IS NULL`, `IS NOT NULL`)
  - Date/time expressions
  - Parentheses for grouping conditions

## Installation

Add `sql_to_flop` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:sql_to_flop, "~> 0.1.0"}
  ]
end
``` 

## Usage

```elixir
iex> SqlToFlop.parse("name = 'John'")
{:ok, [%{field: "name", op: :==, value: "John"}]}
```

```elixir
iex> SqlToFlop.parse("age >= 18 AND status = 'active'")
{:ok, [
  %{field: "age", op: :>=, value: 18},
  %{field: "status", op: :==, value: "active"}
  ]}  
```



```elixir
iex> SqlToFlop.parse("invalid sql")
{:error, "Failed to parse SQL: ..."}
```   

### Supported Operators

- Comparison: `=`, `!=`, `<>`, `>`, `<`, `>=`, `<=`
- Pattern matching: `LIKE`
- Logical: `AND`, `OR`
- List membership: `IN`
- Null checks: `IS NULL`, `IS NOT NULL`
- Date/time: Support for `DATE` and `TIMESTAMP` literals

### Error Handling

```elixir
iex> SqlToFlop.parse("invalid sql")
{:error, "Failed to parse SQL: ..."}
```

### Date/Time Format

The parser supports `DATE` and `TIMESTAMP` literals in the following formats:

```elixir
iex> SqlToFlop.parse("created_at = '2023-01-01 12:00:00'")
{:ok, [%{field: "created_at", op: :==, value: ~U[2023-01-01 12:00:00Z]}]}
```

### IN List Values

The parser supports `IN` list values in the following format:

```elixir
iex> SqlToFlop.parse("status IN ('pending', 'review', 'approved')")
{:ok, [
  %{field: "status", op: :in, value: ["pending", "review", "approved"]}
  ]}
``` 

### Parentheses for Grouping Conditions

The parser supports parentheses for grouping conditions:

```elixir
iex> SqlToFlop.parse("(age >= 18 AND status = 'active') OR (age < 18 AND status = 'inactive')")
{:ok, [
  %{field: "age", op: :>=, value: 18},
  %{field: "status", op: :==, value: "active"}
  ]}
``` 

### Date/Time Format

The parser supports `DATE` and `TIMESTAMP` literals in the following formats:

```elixir
iex> SqlToFlop.parse("created_at = '2023-01-01 12:00:00'")
{:ok, [%{field: "created_at", op: :==, value: ~U[2023-01-01 12:00:00Z]}]}
```

```elixir
iex> SqlToFlop.parse("status IN ('pending', 'review', 'approved')")
{:ok, [
  %{field: "status", op: :in, value: ["pending", "review", "approved"]}
  ]}
```     
