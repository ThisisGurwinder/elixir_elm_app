defmodule Domains.Students.Projections.Students do
	use Ecto.Schema
	import Ecto.Changeset

	alias Domains.Students.Projections.Students

	@primary_key {:students_uuid, :binary_id, autogenerate: false}
end
