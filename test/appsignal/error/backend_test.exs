defmodule Appsignal.Error.BackendTest do
  use ExUnit.Case, async: true
  import AppsignalTest.Utils
  import ExUnit.CaptureIO
  alias Appsignal.{Error.Backend, Span, Tracer, WrappedNif, WrappedTracer, WrappedSpan}

  setup do
    WrappedNif.start_link()
    WrappedTracer.start_link()
    WrappedSpan.start_link()
    :ok
  end

  test "is added as a Logger backend" do
    assert {:error, :already_present} = Logger.add_backend(Backend)
  end

  describe "handle_event/3, when no span exists" do
    setup do
      [pid: spawn(fn -> raise "Exception" end)]
    end

    test "creates a span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{"", nil, ^pid}]} = WrappedTracer.get(:create_span)
      end)
    end

    test "adds an error to the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}, %RuntimeError{message: "Exception"}, stack}]} =
                 WrappedSpan.get(:add_error)

        assert is_list(stack)
      end)
    end

    test "closes the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}}]} = WrappedTracer.get(:close_span)
      end)
    end
  end

  describe "handle_event/3, with an open span" do
    setup do
      parent = self()

      pid =
        spawn(fn ->
          span = Tracer.create_span("")
          send(parent, span)
          raise "Exception"
        end)

      span =
        receive do
          span -> span
        end

      [pid: pid, span: span]
    end

    test "adds an error to the existing span", %{span: span} do
      until(fn ->
        assert {:ok, [{^span, %RuntimeError{message: "Exception"}, _stack}]} =
                 WrappedSpan.get(:add_error)
      end)
    end

    test "closes the existing span", %{span: span, pid: pid} do
      until(fn ->
        assert {:ok, [{^span}]} = WrappedTracer.get(:close_span)
      end)
    end
  end

  describe "handle_event/3, with a :badarg" do
    setup do
      pid =
        spawn(fn ->
          :erlang.error(:badarg)
        end)

      [pid: pid]
    end

    test "creates a span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{"", nil, ^pid}]} = WrappedTracer.get(:create_span)
      end)
    end

    test "adds an error to the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}, %ArgumentError{message: "argument error"}, stack}]} =
                 WrappedSpan.get(:add_error)

        assert is_list(stack)
      end)
    end

    test "closes the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}}]} = WrappedTracer.get(:close_span)
      end)
    end
  end

  describe "handle_event/3, with a Task" do
    setup do
      parent = self()

      spawn(fn ->
        %Task{pid: pid} =
          Task.async(fn ->
            raise "Exception"
          end)

        send(parent, pid)
      end)

      pid =
        receive do
          pid -> pid
        end

      [pid: pid]
    end

    test "creates a span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{"", nil, ^pid}]} = WrappedTracer.get(:create_span)
      end)
    end

    test "adds an error to the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}, %RuntimeError{message: "Exception"}, stack}]} =
                 WrappedSpan.get(:add_error)

        assert is_list(stack)
      end)
    end

    test "closes the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}}]} = WrappedTracer.get(:close_span)
      end)
    end
  end

  describe "handle_event/3, with a crashing GenServer" do
    setup do
      defmodule CrashingGenServer do
        use GenServer

        def start_link(_opts) do
          GenServer.start(__MODULE__, [meta: :data], name: Elixir.MyGenServer)
        end

        def init(opts), do: {:ok, opts}

        def handle_cast(:raise_error, state) do
          Map.fetch!(%{}, :bad_key)

          {:noreply, state}
        end
      end

      {:ok, pid} = start_supervised(CrashingGenServer)

      GenServer.cast(pid, :raise_error)

      [pid: pid]
    end

    test "creates a span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{"", nil, ^pid}]} = WrappedTracer.get(:create_span)
      end)
    end

    test "adds an error to the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}, %KeyError{}, stack}]} = WrappedSpan.get(:add_error)

        assert is_list(stack)
      end)
    end

    test "closes the created span", %{pid: pid} do
      until(fn ->
        assert {:ok, [{%Span{}}]} = WrappedTracer.get(:close_span)
      end)
    end
  end
end
