defmodule Pulse.Util do

  def complement(list1, list2) do
    List.foldl(list2, list1, fn(item, acc) ->
        List.delete(acc, item)
      end)
  end

end
