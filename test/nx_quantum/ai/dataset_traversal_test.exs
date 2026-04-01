defmodule NxQuantum.AI.DatasetTraversalTest do
  use ExUnit.Case, async: true
  alias NxQuantum.AI.Tools.KernelRerank.DatasetCSV

  test "load/1 rejects path traversal to sensitive files" do
    assert {:error, error} = DatasetCSV.load(%{
      dataset_path: "/etc/passwd",
      query_id: "q-1"
    })

    assert error.code == :ai_tool_invalid_request
    assert error.field == :dataset_path
    assert error.message == "unauthorized dataset path"
  end

  test "load/1 rejects sibling directory bypass" do
    # Create a scenario where we have a fake allowed directory and a sibling
    # E.g. bench/datasets and bench/datasets_private
    # We can use System.tmp_dir() for this.
    tmp_dir = System.tmp_dir!()
    allowed_dir = Path.join(tmp_dir, "allowed")
    sibling_dir = Path.join(tmp_dir, "allowed_private")

    File.mkdir_p!(allowed_dir)
    File.mkdir_p!(sibling_dir)

    File.write!(Path.join(sibling_dir, "secret.csv"), "query_id,candidate_id,query_embedding,candidate_embedding\nq-1,d-1,0.1,0.2\n")

    # This should be rejected because it's not in System.tmp_dir!() BUT
    # it's also not in bench/datasets.
    # Actually, in my implementation System.tmp_dir!() IS allowed.
    # So sibling_dir is INSIDE System.tmp_dir!() and thus allowed.

    # To test sibling bypass properly, we'd need to mock the allowed_dirs or
    # find a path outside of the allowed ones that starts with the same prefix.

    # If allowed_dir was /tmp/allowed, /tmp/allowed_private should be rejected
    # if only /tmp/allowed/ was the prefix.

    # Since System.tmp_dir!() is allowed, everything under it is allowed.
    # Let's test against bench/datasets.

    bad_path = Path.expand("bench/datasets_private/secret.csv")
    assert {:error, error} = DatasetCSV.load(%{
      dataset_path: bad_path,
      query_id: "q-1"
    })
    assert error.message == "unauthorized dataset path"
  end

  test "load/1 rejects relative path traversal outside allowed" do
    tmp_dir = System.tmp_dir!()

    # Attempt to go up and out of System.tmp_dir()
    # This assumes System.tmp_dir() is not /
    parent_of_tmp = Path.expand(Path.join(tmp_dir, ".."))

    assert {:error, error} = DatasetCSV.load(%{
      dataset_path: Path.join(parent_of_tmp, "some_file.csv"),
      query_id: "q-1"
    })

    assert error.code == :ai_tool_invalid_request
    assert error.message == "unauthorized dataset path"
  end

  test "load/1 allows valid paths in System.tmp_dir()" do
    tmp_dir = System.tmp_dir!()
    path = Path.join(tmp_dir, "valid_test.csv")
    File.write!(path, "query_id,candidate_id,query_embedding,candidate_embedding\nq-1,d-1,0.1,0.2\nq-1,d-2,0.1,0.3\n")

    assert {:ok, _} = DatasetCSV.load(%{
      dataset_path: path,
      query_id: "q-1"
    })
  end
end
