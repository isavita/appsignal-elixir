defmodule Appsignal.WrappedNif do
  use Wrapper
  alias Appsignal.Nif

  defwrap(Nif, create_root_span(name))
  defwrap(Nif, create_child_span(trace_id, span_id, name))
  defwrap(Nif, close_span(reference))
end
