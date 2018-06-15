defmodule Domains.Students.StudentsRepo do
	use Ecto.Repo, otp_app: :sample_web_app

	def init(_, opts) do
		{:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL")}
	end
end
