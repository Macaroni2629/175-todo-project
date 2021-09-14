require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
  set :port, 1234
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].select { |todo| !todo[:completed]}.size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}

    incomplete_lists.each { |list| yield list }
    complete_lists.each { |list| yield list }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo }
    complete_todos.each { |todo| yield todo }
  end

  def load_list(id)
  list = session[:lists].find{ |list| list[:id] == id }
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

#View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

#Render the new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

#Return an error message if the name is invalid.  Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    "Todo name must be between 1 and 100 characters."
  end
end

#Return an error message if the name is invalid.  Return nil if name is valid.
def error_for_todo(name)
  if !(1..100).cover? name.size
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end


#Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id] # hash - it's one todo list
  session[:lists] # array of hashes, each hash is a list
  @array_of_lists = session[:lists]
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_todo_id(@array_of_lists)
    @array_of_lists << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been added."
    redirect "/lists"
  end
end

#View a single todo list

get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)

  #outside_range?(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
 desired_hash = session[:lists].find { |hash| hash[:id] == id}
 index_of_desired_hash = session[:lists].index(desired_hash)
  @list = session[:lists][index_of_desired_hash]
  #outside_range?(@list_id)
  erb :edit, layout: :layout
end

# renaming an existing todo list

post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  #outside_range?(@list_id)

  error = error_for_list_name(list_name)
  desired_hash = session[:lists].find { |hash| hash[:id] == id}
  index_of_desired_hash = session[:lists].index(desired_hash)


  if error
    session[:error] = error
    erb :edit, layout: :layout
  else
    session[:lists][index_of_desired_hash][:name] = list_name
    session[:success] = "The name of the list has been renamed."
    redirect "/lists/#{id}"
  end
 end

 # Delete a todo list

 post "/lists/:id/destroy" do
  @list_id = params[:id].to_i # this is the id number of the list
  @list = session[:lists].find { |hash| hash[:id] == @list_id} #this is the desired hash/list.
  index_of_desired_hash = session[:lists].index(@list)

   #selected_list = @list.reject! { |list| list[:id] == id }
  session[:lists].delete_at(index_of_desired_hash)
  session[:success] = "The list has been deleted."

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    redirect "/lists"
  end
 end


 def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
 end

 # Add a new to do to a list
 post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = session[:lists].find { |hash| hash[:id] == @list_id}
  #index_of_desired_hash = session[:lists].index(desired_hash)

  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else

    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
 end

 # Delete a todo from a list
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  desired_hash = session[:lists].find { |hash| hash[:id] == @list_id}

  index_of_desired_hash = session[:lists].index(desired_hash)
  todo_id = desired_hash[:todos][index_of_desired_hash][:id]
 
   selected_todo = desired_hash[:todos].find { |todo| todo[:id] == todo_id }
   index_todo = desired_hash[:todos].index(selected_todo)

  desired_hash[:todos].delete(selected_todo)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

#Update the status of a todo

post "/lists/:list_id/todos/:id" do
  #validates checking that list exists
  @list_id = params[:list_id].to_i
  #outside_range?(@list_id)

  desired_hash = session[:lists].find { |hash| hash[:id] == @list_id}
  index_of_desired_hash = session[:lists].index(desired_hash)

  
  @list = session[:lists][@list_id] # returns the list as a hash
  todo_id = params[:id].to_i #returns numeric value of todo
  is_completed = params[:completed] == "true"
  selected_todo = desired_hash[:todos].find { |todo| todo[:id] == todo_id }
  selected_todo[:completed] = is_completed
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"

end

post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  #outside_range?(@list_id)
  @list = session[:lists] # array of lists/hashes

  @list.each do |hash|
    hash[:todos].each do |todo|
      todo[:completed] = true
    end
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end