defmodule SqlToEcto do
    @moduledoc """
  Converts SQL select, WHERE, ORDER BY, and OFFSET clauses to Ecto queries.

  This module provides functionality to parse SQL-like query strings and convert them
  into equivalent Ecto query expressions. It supports:
  - SELECT expressions for field selection
  - WHERE conditions with comparison operators
  - ORDER BY clauses with ASC/DESC directions
  - OFFSET for pagination
  - GROUP BY for aggregations

  ## Supported Operators

  The following operators are supported in WHERE conditions:
  - `=` - Equality
  - `>` - Greater than
  - `<` - Less than
  - `>=` - Greater than or equal
  - `<=` - Less than or equal
  - `LIKE` - Pattern matching
  - `NOT LIKE` - Negative pattern matching
  - `NOT` - Negation
  - `IN` - List membership
  - `NOT IN` - Negative list membership

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

  The main function is `to_ecto_query/2`, which takes a SQL-like query string and a schema module:

  ```elixir
  # Basic SELECT with WHERE
  iex> sql = "SELECT name, age WHERE age > 21"
  iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
  #Ecto.Query<from u in MyApp.User, where: u.age > ^21, select: [:name, :age]>

  # SELECT with multiple WHERE conditions
  iex> sql = "SELECT name WHERE age >= 21 AND city = 'New York'"
  iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
  #Ecto.Query<from u in MyApp.User, where: u.age >= ^21 and u.city == ^"New York", select: [:name]>

  # Using ORDER BY and OFFSET
  iex> sql = "SELECT name, created_at WHERE active = 'true' ORDER BY created_at DESC OFFSET 10"
  iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
  #Ecto.Query<from u in MyApp.User, where: u.active == ^"true", select: [:name, :created_at], order_by: [desc: u.created_at], offset: ^10>

  # Using GROUP BY
  iex> sql = "SELECT city WHERE country = 'USA' GROUP BY city"
  iex> SqlToEcto.to_ecto_query(sql, MyApp.User)
  #Ecto.Query<from u in MyApp.User, where: u.country == ^"USA", group_by: [u.city], select: [:city]>
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
  """

  import Ecto.Query

  import NimbleParsec

  # Basic parsers
  whitespace =
    ascii_string([?\s, ?\t, ?\n, ?\r], min: 1)
    |> ignore()

  optional_whitespace =
    ascii_string([?\s, ?\t, ?\n, ?\r], min: 0)
    |> ignore()

  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 0)
    |> reduce({List, :to_string, []})

  integer =
    ascii_string([?0..?9], min: 1)
    |> reduce({List, :to_string, []})
    |> map({String, :to_integer, []})

  string_literal =
    ignore(ascii_char([?']))
    |> ascii_string([not: ?'], min: 0)
    |> ignore(ascii_char([?']))

  # Operators
  operator =
    ignore(optional_whitespace)
    |> choice([
      string("NOT LIKE") |> replace(:not_like),
      string("NOT IN") |> replace(:not_in),
      string("NOT") |> replace(:not),
      string(">=") |> replace(:gte),
      string("<=") |> replace(:lte),
      string("=") |> replace(:eq),
      string(">") |> replace(:gt),
      string("<") |> replace(:lt),
      string("LIKE") |> replace(:like),
      string("IN") |> replace(:in)
    ])

  # Field list parser
  defparsecp :parse_select_fields,
    identifier
    |> map({:process_identifier, []})
    |> repeat(
      ignore(optional_whitespace)
      |> ignore(ascii_char([?,]))
      |> ignore(optional_whitespace)
      |> concat(identifier)
      |> map({:process_identifier, []})
    )
    |> wrap()
    |> map({:wrap_select_fields, []})

  defp process_identifier(value), do: value

  # WHERE condition parser
  defparsecp :parse_where_condition,
    identifier
    |> ignore(whitespace)
    |> concat(operator)
    |> ignore(whitespace)
    |> choice([integer, string_literal])
    |> wrap()
    |> map({:wrap_where_condition, []})

  # ORDER BY parser
  defparsecp :parse_order_by,
    identifier
    |> ignore(whitespace)
    |> choice([
      string("DESC") |> replace(:desc),
      string("ASC") |> replace(:asc)
    ])
    |> wrap()
    |> map({:wrap_order_by, []})

  # OFFSET parser
  defparsecp :parse_offset,
    integer
    |> map({:wrap_offset, []})

  # GROUP BY parser
  defparsecp :parse_group_by,
    identifier
    |> repeat(
      ignore(optional_whitespace)
      |> ignore(ascii_char([?,]))
      |> ignore(optional_whitespace)
      |> concat(identifier)
    )
    |> wrap()
    |> map({:wrap_group_by, []})

  # Main query parser
  defparsec :parse_query,
    ignore(optional_whitespace)
    |> ignore(string("SELECT"))
    |> ignore(whitespace)
    |> concat(parsec(:parse_select_fields))
    |> optional(
      ignore(whitespace)
      |> ignore(string("WHERE"))
      |> ignore(whitespace)
      |> choice([
        string("NOT") |> replace(:not)
        |> ignore(whitespace)
        |> concat(parsec(:parse_where_condition)),
        parsec(:parse_where_condition)
      ])
      |> repeat(
        ignore(whitespace)
        |> choice([
          string("AND") |> replace({:conjunction, :and}),
          string("OR") |> replace({:conjunction, :or})
        ])
        |> ignore(whitespace)
        |> choice([
          string("NOT") |> replace(:not)
          |> ignore(whitespace)
          |> concat(parsec(:parse_where_condition)),
          parsec(:parse_where_condition)
        ])
      )
    )
    |> optional(
      ignore(whitespace)
      |> ignore(string("GROUP BY"))
      |> ignore(whitespace)
      |> concat(parsec(:parse_group_by))
    )
    |> optional(
      ignore(whitespace)
      |> ignore(string("ORDER BY"))
      |> ignore(whitespace)
      |> concat(parsec(:parse_order_by))
    )
    |> optional(
      ignore(whitespace)
      |> ignore(string("OFFSET"))
      |> ignore(whitespace)
      |> concat(parsec(:parse_offset))
    )
    |> ignore(optional_whitespace)

  # Helper functions for wrapping parsed results
  defp wrap_select_fields(fields), do: {:select_fields, fields}
  defp wrap_where_condition([field, operator, value]), do: {:where_condition, [field, operator, value]}
  defp wrap_order_by([field, direction]), do: {:order_by_expr, [field, direction]}
  defp wrap_offset(value), do: {:offset_expr, value}
  defp wrap_group_by(fields), do: {:group_by_expr, fields}

  # Query building functions
  def to_ecto_query(sql_string, schema) when is_binary(sql_string) do
    case parse_query(sql_string) do
      {:ok, parsed, "", _, _, _} ->
        build_ecto_query(parsed, schema)
      _ ->
        raise ArgumentError, "Invalid SQL query"
    end
  end

  defp build_ecto_query(parsed, schema) do
    {query, _} = Enum.reduce(parsed, {schema, nil}, &build_query_part/2)
    query
  end

  # Handle initial WHERE condition
  defp build_query_part({:where_condition, [field, op, value]}, {query, nil}) do
    field = String.to_existing_atom(field)
    where_expr = build_where_condition(field, op, value)
    {from(q in query, where: ^where_expr), where_expr}
  end

  defp build_query_part(:not, {query, prev_where}) do
    {query, {:not, prev_where}}
  end

  # Handle AND/OR conditions
  defp build_query_part({:conjunction, conjunction_type}, {query, prev_where}) do
    {query, {:conjunction, conjunction_type, prev_where}}
  end

  # Handle WHERE after NOT
  defp build_query_part({:where_condition, [field, op, value]}, {query, {:not, _prev_where}}) do
    field = String.to_existing_atom(field)
    where_expr = build_where_condition(field, op, value)
    negated_expr = dynamic([q], not(^where_expr))
    {from(q in query, where: ^negated_expr), negated_expr}
  end

  # Handle WHERE after AND
  defp build_query_part({:where_condition, [field, op, value]}, {query, {:conjunction, :and, prev_where}}) do
    field = String.to_existing_atom(field)
    where_expr = build_where_condition(field, op, value)
    combined_where = dynamic([q], ^prev_where and ^where_expr)
    {from(q in query, where: ^combined_where), combined_where}
  end

  # Handle WHERE after OR
  defp build_query_part({:where_condition, [field, op, value]}, {query, {:conjunction, :or, prev_where}}) do
    field = String.to_existing_atom(field)
    where_expr = build_where_condition(field, op, value)
    combined_where = dynamic([q], ^prev_where or ^where_expr)
    {from(q in query, where: ^combined_where), combined_where}
  end

  # Handle SELECT fields
  defp build_query_part({:select_fields, fields}, {query, where_expr}) do
    fields = Enum.map(fields, &String.to_existing_atom/1)
    {from(q in query, select: ^fields), where_expr}
  end

  # Handle ORDER BY
  defp build_query_part({:order_by_expr, [field, direction]}, {query, where_expr}) do
    field = String.to_existing_atom(field)
    {from(q in query, order_by: [{^direction, ^field}]), where_expr}
  end

  # Handle OFFSET
  defp build_query_part({:offset_expr, offset}, {query, where_expr}) do
    {from(q in query, offset: ^offset), where_expr}
  end

  # Handle GROUP BY
  defp build_query_part({:group_by_expr, fields}, {query, where_expr}) do
    fields = Enum.map(fields, &String.to_existing_atom/1)
    {from(q in query, group_by: ^fields), where_expr}
  end

  defp build_where_condition(field, :eq, value), do: dynamic([q], field(q, ^field) == ^value)
  defp build_where_condition(field, :gt, value), do: dynamic([q], field(q, ^field) > ^value)
  defp build_where_condition(field, :lt, value), do: dynamic([q], field(q, ^field) < ^value)
  defp build_where_condition(field, :gte, value), do: dynamic([q], field(q, ^field) >= ^value)
  defp build_where_condition(field, :lte, value), do: dynamic([q], field(q, ^field) <= ^value)
  defp build_where_condition(field, :like, value), do: dynamic([q], like(field(q, ^field), ^value))
  defp build_where_condition(field, :not_like, value), do: dynamic([q], not like(field(q, ^field), ^value))
  defp build_where_condition(field, :not, value), do: dynamic([q], not(field(q, ^field) == ^value))
end
