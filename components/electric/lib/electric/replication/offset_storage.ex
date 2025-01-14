defmodule Electric.Replication.OffsetStorage do
  @moduledoc """
  Public interface for replication state storage

  The server process starts the storage and does occasional garbage collection
  """
  use GenServer
  require Logger

  alias Electric.Postgres.Lsn, as: PGLsn
  alias Electric.Satellite.Lsn, as: STLsn

  @table Module.concat([__MODULE__, Table])

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    default_file = Application.fetch_env!(:electric, __MODULE__) |> Keyword.fetch!(:file)

    opts =
      Keyword.merge([file: default_file, type: :set], opts)
      |> Keyword.update!(:file, &String.to_charlist/1)

    dets = :dets.open_file(@table, opts)

    {:ok, dets}
  end

  @doc "Persist satellite lsn"
  @spec put_satellite_lsn(String.t(), STLsn.t()) :: :ok
  def put_satellite_lsn(satellite_client, lsn) do
    Logger.info("Saving lsn #{inspect(lsn)} for satellite: #{inspect(satellite_client)}")
    :ok = :dets.insert(@table, {{:st, satellite_client}, lsn})
    :dets.sync(@table)
  end

  @spec get_satellite_lsn(String.t()) :: nil | STLsn.t()
  def get_satellite_lsn(satellite_client) do
    case :dets.lookup(@table, {:st, satellite_client}) do
      [] -> nil
      [{{:st, _}, lsn}] -> lsn
    end
  end

  @doc """
  Store a mapping of the LSN being sent to a Postgres slot and
  actual position in a log that feeds the Postgres.
  """
  def save_pg_position(slot, lsn, offset) do
    Logger.info(
      "Saving offset #{inspect(offset)} for lsn #{inspect(lsn)} and slot #{inspect(slot)}"
    )

    :ok = :dets.insert(@table, {{slot, lsn}, offset})
    :dets.sync(@table)
  end

  @doc """
  Get position of the previously-connected PostgreSQL slot.

  Maps postgres-sent "continue" LSN to a previously stored position in a log
  that feeds the Postgres. The position is saved by the `save_pg_position/3`
  """
  @spec get_pg_position(String.t(), PGLsn) :: nil | term()
  def get_pg_position(slot, lsn) do
    case :dets.lookup(@table, {slot, lsn}) do
      [] -> nil
      [{{_slot, _lsn}, offset}] -> offset
    end
  end

  # FIXME: could stream + reduce to reduce memory footprint in case of large
  # datasets
  def get_largest_known_lsn_smaller_than(slot, max) do
    @table
    |> :dets.select([{{{:"$1", :"$2"}, :"$3"}, [{:==, :"$1", slot}], [{{:"$2", :"$3"}}]}])
    |> Enum.filter(fn {lsn1, _} -> PGLsn.compare(lsn1, max) != :gt end)
    |> Enum.max(fn {lsn1, _}, {lsn2, _} -> PGLsn.compare(lsn1, lsn2) != :lt end, fn -> nil end)
  end

  # TODO: :)
  def garbage_collect_relations() do
    raise ArgumentError, "not implemented"
  end

  def terminate(_reason) do
    Logger.info("Syncing storage")
    :dets.sync(@table)
  end
end
