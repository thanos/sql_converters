

defmodule SqlToFlop do
 @moduledoc """
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

  ## Basic Usage

      # Simple equality comparison
      SqlToFlop.parse("name = 'John'")
      # Returns: {:ok, [%{field: "name", op: :==, value: "John"}]}

      # Multiple conditions with AND
      SqlToFlop.parse("age >= 18 AND status = 'active'")
      # Returns: {:ok, [
      #   %{field: "age", op: :>=, value: 18},
      #   %{field: "status", op: :==, value: "active"}
      # ]}

      # Using OR conditions
      SqlToFlop.parse("status = 'pending' OR status = 'review'")
      # Returns: {:ok, [
      #   %{field: "status", op: :==, value: "pending"},
      #   %{field: "status", op: :==, value: "review", or: true}
      # ]}

  ## Advanced Examples

      # NULL checks
      SqlToFlop.parse("deleted_at IS NULL")
      # Returns: {:ok, [%{field: "deleted_at", op: :is_null}]}

      # IN operator
      SqlToFlop.parse("category IN ('books', 'movies')")
      # Returns: {:ok, [%{field: "category", op: :in, value: ["books", "movies"]}]}

      # Date comparisons
      SqlToFlop.parse("created_at > DATE '2024-01-01'")
      # Returns: {:ok, [%{field: "created_at", op: :>, value: ~D[2024-01-01]}]}

      # Timestamp comparisons
      SqlToFlop.parse("updated_at < TIMESTAMP '2024-03-15 14:30:00'")
      # Returns: {:ok, [%{field: "updated_at", op: :<, value: ~N[2024-03-15 14:30:00]}]}

      # Grouped conditions
      SqlToFlop.parse("(status = 'active' AND age >= 18) OR verified = true")
      # Returns: {:ok, [
      #   %{conditions: [
      #     %{field: "status", op: :==, value: "active"},
      #     %{field: "age", op: :>=, value: 18}
      #   ], group: true},
      #   %{field: "verified", op: :==, value: true, or: true}
      # ]}

  ## Supported Operators

  - Comparison: `=`, `!=`, `<>`, `>`, `<`, `>=`, `<=`
  - Pattern matching: `LIKE`
  - Logical: `AND`, `OR`
  - List membership: `IN`
  - Null checks: `IS NULL`, `IS NOT NULL`
  - Date/Time: Support for `DATE` and `TIMESTAMP` literals
  """

import NimbleParsec

# Whitespace
whitespace = ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)
defcombinator :ignore_whitespace, optional(whitespace) |> ignore()

# Basic tokens
identifier =
  ascii_string([?a..?z, ?A..?Z, ?_], 1)
  |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?.], min: 0)
  |> reduce({Enum, :join, [""]})

# Operators
equals = string("=") |> replace(:==)
not_equals = choice([string("!="), string("<>")])  |> replace(:!=)
greater_than = string(">") |> replace(:>)
less_than = string("<") |> replace(:<)
greater_equals = string(">=") |> replace(:>=)
less_equals = string("<=") |> replace(:<=)
like = string("LIKE") |> parsec(:ignore_whitespace) |> replace(:like)
is_null = string("IS NULL") |> replace(:is_null)
is_not_null = string("IS NOT NULL") |> replace(:is_not_null)
in_op = string("IN") |> replace(:in)

operator =
  choice([
    is_not_null,
    is_null,
    equals,
    not_equals,
    greater_equals,
    less_equals,
    greater_than,
    less_than,
    like,
    in_op
  ])

# Values
integer =
  optional(ascii_char([?-]))
  |> ascii_string([?0..?9], min: 1)
  |> reduce({:to_integer, []})

string_literal =
  ignore(ascii_char([?']))
  |> ascii_string([not: ?'], min: 0)
  |> ignore(ascii_char([?']))

boolean_literal =
  choice([
    string("true") |> replace(true),
    string("false") |> replace(false)
  ])

# Date/Time formats
date =
  string("DATE '")
  |> ascii_string([?0..?9], 4)
  |> ignore(ascii_char([?-]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?-]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?']))
  |> reduce(:parse_date)

timestamp =
  string("TIMESTAMP '")
  |> ascii_string([?0..?9], 4)
  |> ignore(ascii_char([?-]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?-]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?\s]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?:]))
  |> ascii_string([?0..?9], 2)
  |> ignore(ascii_char([?:]))
  |> ascii_string([?0..?9], 2)
  |> optional(
    ignore(ascii_char([?.]))
    |> ascii_string([?0..?9], min: 1, max: 6)
  )
  |> ignore(ascii_char([?']))
  |> reduce(:parse_timestamp)

# IN list values
in_list_value =
  ignore(ascii_char([?(]))
  |> repeat(
    parsec(:ignore_whitespace)
    |> choice([integer, string_literal])
    |> ignore(optional(string(",")))
    |> parsec(:ignore_whitespace)
  )
  |> ignore(ascii_char([?)]))

value = choice([
  date,
  timestamp,
  integer,
  string_literal,
  boolean_literal
])

# Logical operators
and_op = string("AND") |> replace(:and)
or_op = string("OR") |> replace(:or)
logical_op = choice([and_op, or_op])

# Forward declare parsers for recursive definitions
defparsecp :condition_parser, parsec(:condition)
defparsecp :conditions_parser, parsec(:conditions)

# Single condition
null_condition =
  identifier
  |> parsec(:ignore_whitespace)
  |> choice([is_null, is_not_null])
  |> reduce(:build_null_condition)

in_condition =
  identifier
  |> parsec(:ignore_whitespace)
  |> concat(in_op)
  |> parsec(:ignore_whitespace)
  |> concat(in_list_value)
  |> reduce(:build_in_condition)

comparison_condition =
  identifier
  |> parsec(:ignore_whitespace)
  |> concat(operator)
  |> parsec(:ignore_whitespace)
  |> concat(value)
  |> reduce(:build_condition)

# Parenthesized group
parenthesized =
  ignore(ascii_char([?(]))
  |> parsec(:ignore_whitespace)
  |> parsec(:conditions_parser)
  |> parsec(:ignore_whitespace)
  |> ignore(ascii_char([?)]))
  |> reduce(:build_group)

# Define condition to handle all types
defcombinator :condition, choice([
  parenthesized,
  null_condition,
  in_condition,
  comparison_condition
])

# Multiple conditions
defcombinator :conditions,
  parsec(:condition_parser)
  |> repeat(
    parsec(:ignore_whitespace)
    |> concat(logical_op)
    |> parsec(:ignore_whitespace)
    |> parsec(:condition_parser)
  )

defparsec :parse_sql, parsec(:conditions)

@doc """
Parses a SQL WHERE clause into Flop filter parameters.

## Parameters

- `sql`: String containing a SQL WHERE clause

## Returns

- `{:ok, filters}` where filters is a list of Flop filter parameters
- `{:error, reason}` if parsing fails

## Examples

    iex> SqlToFlop.parse("name = 'John'")
    {:ok, [%{field: "name", op: :==, value: "John"}]}

    iex> SqlToFlop.parse("age >= 18 AND status = 'active'")
    {:ok, [
      %{field: "age", op: :>=, value: 18},
      %{field: "status", op: :==, value: "active"}
    ]}

    iex> SqlToFlop.parse("invalid sql")
    {:error, "Failed to parse SQL: ..."}
"""
def parse(sql_string) when is_binary(sql_string) do
  case parse_sql(sql_string) do
    {:ok, parsed, "", _, _, _} ->
      {:ok, process_conditions(parsed)}
    {:error, reason, _, _, _, _} ->
      {:error, "Failed to parse SQL: #{reason}"}
  end
end

# Helper functions
defp build_condition([field, op, value]) do
  %{field: field, op: op, value: value}
end

defp build_null_condition([field, op]) do
  %{field: field, op: op}
end

defp build_in_condition([field, :in, values]) do
  %{field: field, op: :in, value: values}
end

defp build_group([conditions]) do
  %{conditions: process_conditions(conditions), group: true}
end

defp parse_date([_, year, month, day]) do
  {:ok, date} = Date.new(String.to_integer(year), String.to_integer(month), String.to_integer(day))
  date
end

defp parse_timestamp([_, year, month, day, hour, minute, second | rest]) do
  microsecond = case rest do
    [fraction] -> {String.to_integer(fraction) * 1_000, 6}
    [] -> {0, 0}
  end

  {:ok, naive_dt} = NaiveDateTime.new(
    String.to_integer(year),
    String.to_integer(month),
    String.to_integer(day),
    String.to_integer(hour),
    String.to_integer(minute),
    String.to_integer(second),
    microsecond
  )
  naive_dt
end

defp process_conditions(conditions) do
  conditions
  |> Enum.chunk_every(2)
  |> Enum.map(fn
    [condition] -> condition
    [condition1, :and] -> condition1
    [condition1, :or] -> Map.put(condition1, :or, true)
  end)
end

defp to_integer(chars) when is_list(chars) do
  chars |> Enum.join() |> String.to_integer()
end
end
