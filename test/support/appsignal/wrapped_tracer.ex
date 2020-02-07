defmodule Appsignal.WrappedTracer do
  use Wrapper
  alias Appsignal.Tracer

  defdelegate current_span(pid), to: Tracer

  defwrap(Tracer, create_span(name, parent, pid))
  defwrap(Tracer, close_span(span))
end
