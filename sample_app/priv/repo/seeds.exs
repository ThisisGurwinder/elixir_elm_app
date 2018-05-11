
alias SampleApp.Students.Student
alias SampleApp.Repo

students = [
  %{name: "James T Kirk", age: 30, subject: "Humility", classification: "Masters"},
  %{name: "Jean-Luc Picard", age: 40, subject: "Hair Dressing", classification: "BTEC"},
  %{name: "Kathryn Janeway", age: 35, subject: "Map Reading", classification: "BSc"}
]

students
|> Enum.each(fn(student) ->
  %Student{} |> Student.changeset(student) |> Repo.insert!
end)
