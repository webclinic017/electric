defmodule Electric.Postgres.Extension.SchemaLoader do
  alias Electric.Postgres.{Schema, Extension.Migration}
  alias Electric.Replication.Connectors

  @type state() :: term()
  @type version() :: String.t()
  @type name() :: String.t()
  @type schema() :: name()
  @type relation() :: {schema(), name()}
  @type oid() :: integer()
  @type ddl() :: String.t()
  @type rel_type() :: :table | :index | :view | :trigger
  @type oid_result() :: {:ok, integer()} | {:error, term()}
  @type pk_result() :: {:ok, [name()]} | {:error, term()}
  @type oid_loader() :: (rel_type(), schema(), name() -> oid_result())
  @type table() :: Electric.Postgres.Replication.Table.t()

  @callback connect(Connectors.config(), Keyword.t()) :: {:ok, state()}
  @callback load(state()) :: {:ok, version(), Schema.t()}
  @callback load(state(), version()) :: {:ok, version(), Schema.t()} | {:error, binary()}
  @callback save(state(), version(), Schema.t(), [String.t()]) :: {:ok, state()}
  @callback relation_oid(state(), rel_type(), schema(), name()) :: oid_result()
  @callback primary_keys(state(), schema(), name()) :: pk_result()
  @callback primary_keys(state(), relation()) :: pk_result()
  @callback refresh_subscription(state(), name()) :: :ok | {:error, term()}
  @callback migration_history(state(), version() | nil) ::
              {:ok, [Migration.t()]} | {:error, term()}
  @callback known_migration_version?(state(), version()) :: boolean
  @callback electrified_tables(state()) :: {:ok, [table()]} | {:error, term()}

  @default_backend {__MODULE__.Epgsql, []}

  def get(opts, key, default \\ @default_backend) do
    case Keyword.get(opts, key, default) do
      module when is_atom(module) ->
        {module, []}

      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, opts}
    end
  end

  def connect({module, opts}, conn_config) do
    with {:ok, state} <- module.connect(conn_config, opts) do
      {:ok, {module, state}}
    end
  end

  def load({module, state}) do
    module.load(state)
  end

  def load({module, state}, version) do
    module.load(state, version)
  end

  def save({module, state}, version, schema, stmts) do
    with {:ok, state} <- module.save(state, version, schema, stmts) do
      {:ok, {module, state}}
    end
  end

  def relation_oid({module, state}, rel_type, schema, table) do
    module.relation_oid(state, rel_type, schema, table)
  end

  def primary_keys({module, state}, schema, table) do
    module.primary_keys(state, schema, table)
  end

  def primary_keys({_module, _state} = impl, {schema, table}) do
    primary_keys(impl, schema, table)
  end

  def refresh_subscription({module, state}, name) do
    module.refresh_subscription(state, name)
  end

  def migration_history({module, state}, version) do
    module.migration_history(state, version)
  end

  def known_migration_version?({module, state}, version) do
    module.known_migration_version?(state, version)
  end

  def electrified_tables({module, state}) do
    module.electrified_tables(state)
  end
end
