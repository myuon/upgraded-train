module PathUtils

function change_base_path(filepath::String, new_base::String)
  dir, _ = splitdir(filepath)
  return joinpath(dir, new_base)
end

export change_base_path

end
