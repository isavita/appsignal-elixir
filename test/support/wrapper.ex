defmodule Wrapper do
  defmacro __using__(_) do
    quote do
      import Wrapper
      import ExUnit.Assertions

      def start_link do
        {:ok, pid} = Agent.start_link(fn -> %{} end, name: __MODULE__)

        ExUnit.Callbacks.on_exit(fn ->
          ref = Process.monitor(pid)
          assert_receive {:DOWN, ^ref, _, _, _}, 500
        end)

        {:ok, pid}
      end

      def get(key) do
        Agent.get(__MODULE__, &Map.fetch(&1, key))
      end

      defp add(key, value) do
        Agent.get_and_update(__MODULE__, fn state ->
          Map.get_and_update(state, key, fn current ->
            case current do
              nil -> {nil, [value]}
              _ -> {current, [value | current]}
            end
          end)
        end)
      end
    end
  end

  defmacro defwrap(module, fun) do
    fun = Macro.escape(fun, unquote: true)

    quote bind_quoted: [module: module, fun: fun] do
      {name, args} = Macro.decompose_call(fun)

      def unquote(name)(unquote_splicing(args)) do
        add(unquote(name), {unquote_splicing(args)})
        unquote(module).unquote(name)(unquote_splicing(args))
      end
    end
  end
end
