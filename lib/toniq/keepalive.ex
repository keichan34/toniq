# Responsible for ensuring the erlang vm is connected to the redis server. If
# the connection fails, this will crash and the supervisor will restart toniq.

# Each time this starts it generates a new identifier used to scope job persistence.

# Other processes handles re-queuing of jobs.

defmodule Toniq.Keepalive do
  use GenServer

  def start_link(name \\ __MODULE__, scope \\ Toniq.KeepalivePersistence.default_scope) do
    identifier = UUID.uuid1()
    GenServer.start_link(__MODULE__, %{ identifier: identifier, scope: scope }, name: name)
  end

  def identifier(name \\ __MODULE__) do
    GenServer.call(name, :identifier)
  end

  # private

  def init(state) do
    send self, :register_vm
    {:ok, state}
  end

  def handle_call(:identifier, _from, state) do
    {:reply, state.identifier, state}
  end

  def handle_info(:register_vm, state) do
    Toniq.KeepalivePersistence.register_vm(state.identifier, state.scope)

    update_alive_key(state)
    :timer.send_interval keepalive_interval, :update_alive_key

    {:noreply, state}
  end

  def handle_info(:update_alive_key, state) do
    update_alive_key(state)

    {:noreply, state}
  end

  defp update_alive_key(state) do
    Toniq.KeepalivePersistence.update_alive_key(state.identifier, keepalive_expiration, state.scope)
  end

  defp keepalive_interval,   do: Application.get_env(:toniq, :keepalive_interval)
  defp keepalive_expiration, do: Application.get_env(:toniq, :keepalive_expiration)
end
