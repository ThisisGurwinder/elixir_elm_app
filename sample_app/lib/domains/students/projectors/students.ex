defmodule Domains.Students.Projectors.Students do
	use Commanded.Projections.Ecto,
		name: "Domains.Students.Projectors.Students",
		repo: Domains.Students.StudentsRepo,
		consistency: :strong

	alias Domains.Students.Events.{
		StudentsAdded
	}

	alias Domians.Students.Projections.{Students}
	
end
