defmodule Ctf.Board do
  @enforce_keys [:players, :flags, :obstacles, :width, :height, :events]
  defstruct players: nil, flags: nil, obstacles: [], width: nil, height: nil, events: nil

  alias Ctf.{Player, Obstacle, Flag}

  @type t() :: %__MODULE__{
          players: [Player.t],
          flags: [Flag.t],
          obstacles: List.t,
          width: Integer.t,
          height: Integer.t,
          events: [Tuple.t()]
  }

  @direction_notation [n: "\u02C4", s: "\u02C5", e: "\u02C3", w: "\u02C2"]

  def new(height: height,
          width: width,
          players: [%{}, %{}] = players_spec,
          obstacle_count: obstacle_count) do

    {cells_with_flags, flags} = place_flags(
      %{},
      width,
      height
    )

    {cells_with_players, players} = place_players(
      cells_with_flags,
      width,
      height,
      players_spec,
      flags
    )

    {_cells_with_obstacles, obstacles} = place_obstacles(
      cells_with_players,
      width,
      height,
      obstacle_count
    )

    %__MODULE__{
      players: players,
      flags: flags,
      obstacles: obstacles,
      width: width,
      height: height,
      events: []
    }
  end

  # assumes x and y are within bounds
  def get_cell_contents(%__MODULE__{} = board, x, y) do
    Enum.reduce([:flags, :players, :obstacles], [], fn type, acc ->
      things_of_type = Map.from_struct(board)[type]
      Enum.filter(things_of_type, fn thing -> thing.x == x && thing.y == y end) ++ acc
    end)
  end

  def is_empty(%__MODULE__{} = board, x, y) do
    case get_cell_contents(board, x, y) do
      [] -> true
      _ -> false
    end
  end

  def dump(%__MODULE__{} = board) do
    [
      "\n\n",
      for y <- 0..(board.height - 1) do
        for x <- 0..(board.width - 1) do
          case get_cell_contents(board, x, y) do
            [] ->
              [IO.ANSI.blue(), "__"]
            [%Obstacle{} | _] ->
              [IO.ANSI.red(), "XX"]
            [%Player{number: number, direction: direction} | _] ->
              [IO.ANSI.yellow(), "#{number}#{@direction_notation[direction]}"]
            [%Flag{number: number} | _] ->
              [IO.ANSI.green(), "F#{number}"]
          end ++ [IO.ANSI.reset(), " "]
        end ++ ["\n"]
      end,
      IO.ANSI.reset(),
      "\n\n"
    ]
    |> IO.puts()
  end

  defp place_players(cells, width, height, players, flags) do
    Enum.reduce(
      Enum.zip([[:upper_left, :lower_right], players, flags]),
      {cells, []},
      fn {quadrant, player, flag}, {board, acc} ->
        {x, y} = empty_cell(quadrant, board, width, height)

        player =
          Player.new(
            number: flag.number,
            flag: flag,
            x: x,
            y: y,
            health_points: player.health_points,
            module: player.module,
            direction:
              case quadrant do
                :upper_left -> :s
                :lower_right -> :n
              end
          )

        {place_blindly(board, x, y, player), acc ++ [player]}
      end
    )
  end

  defp place_flags(cells, width, height) do
    Enum.reduce(
      Enum.zip([[:upper_left, :lower_right], 1..2]),
      {cells, []},
      fn {quadrant, number}, {board, flags} ->
        {x, y} = empty_cell(quadrant, board, width, height)
        flag = Flag.new(number: number, x: x, y: y)
        {place_blindly(board, x, y, flag), flags ++ [flag]}
      end
    )
  end

  defp place_obstacles(cells, width, height, count, obstacles \\ [])
  defp place_obstacles(cells, _, _, 0, obstacles), do: {cells, obstacles}

  defp place_obstacles(cells, width, height, count, obstacles) do
    {x, y} = empty_cell(:all, cells, width, height)
    obstacle = Obstacle.new(x: x, y: y)

    place_obstacles(
      place_blindly(cells, x, y, obstacle),
      width,
      height,
      count - 1,
      [obstacle | obstacles]
    )
  end

  # in other words, no collision detection on this placement
  defp place_blindly(cells, x, y, thing) do
    row = cells[x] || %{}
    Map.put(cells, x, Map.put(row, y, thing))
  end

  defp empty_cell(:upper_left, cells, width, height) do
    empty_cell(:all, cells, trunc(width / 3), trunc(height / 3))
  end

  defp empty_cell(:lower_right, cells, width, height) do
    x_shift = trunc(width / 3)
    y_shift = trunc(height / 3)
    {x, y} = empty_cell(:all, cells, x_shift, y_shift)
    {x + x_shift * 2, y + y_shift * 2}
  end

  defp empty_cell(:all, cells, width, height) do
    fn ->
      {trunc(:rand.uniform() * width), trunc(:rand.uniform() * height)}
    end
    |> Stream.repeatedly()
    |> Stream.filter(fn {x, y} -> x < width && y < height end)
    |> Enum.find(&is_nil(get_in(cells, Tuple.to_list(&1))))
  end
end
