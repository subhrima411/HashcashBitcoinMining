#This is the GenServer module which has the init, start_link, handle_call and handle_cast functions" 
defmodule Server do
  use GenServer
  
  #The GenServer is started using this function
  def start_link(k) do
    GenServer.start_link(__MODULE__, k, name: :gens) 
  end

  #The GenServer is initialized with initial k, which is the required number of leading zeroes
  def init(k) do
    {:ok, k}
  end

  #This is called when the worker asks for the required number of leading zeroes
  def handle_call(:msg, _from, zeroes) do
    {:reply, zeroes, zeroes}
  end

  #This is called when the worker asks for a random string to mine bitcoins
  def handle_call(:get_str, _from, zeroes) do
      str = "soumyasen;kjsdfk" <> RandomizeStrings.randomizer(10)
      {:reply, str, zeroes}
  end

  #This is called when the worker wants to send back the mined bitcoin. 
  #This is asynchronous and does not block execution flow.
  def handle_cast({:send_hash, hash}, state) do
    IO.puts hash
    {:noreply, state}
  end

  #This function is called when the worker on the server mines bitcoins
  def spawnThreadsServer(count, intx, zeroes, server_ip, k) do
    if count === intx do
      raise "Maximum number of threads reached!"
      :break
    else
      random_str = "soumyasen;kjsdfk" <> RandomizeStrings.randomizer(10)
      spawn(Hashing, :bitcoinHashing, [random_str, 0, zeroes, server_ip, k])
      spawnThreadsServer(count+1, intx, zeroes, server_ip, k)
    end
  end
end

#This module has the main function and checks if k is a number or an IP address.
#Execution is carried out accordingly."
defmodule MainServer do
  def main(args) do
    args |> parse_args  
  end
    
  defp parse_args([]) do
    IO.puts "No arguments given. Enter the value of k again"
  end

  defp parse_args(args) do
    {_, [k], _} = OptionParser.parse(args)
     
     #First we check whether the input type is an IP address or a numeric value. 
     #If it's a numeric value, then the main server is mining bitcoins on his server 
     #If it's an IP address, the worker asks for work from the Server and mines bitcoins.
     
     if String.match?(k, ~r/[\d]+\.[\d]+\.[\d]+\.[\d]+/) do
        client = RandomizeStrings.randomizer(6) <> "@" <> k
        server_ip = String.to_atom("serv@" <> k)
        Worker.initialize_worker(server_ip)
        Worker.get_zeroes(server_ip, k)
      else 
        #Start the server and initialize with the k value, which is the number of leading zeroes
        server_ip = String.to_atom("serv@"<>findIP)
        Node.start(server_ip)
        Node.set_cookie :'chocolate'
        Server.start_link(k)
        zeroes = String.duplicate("0", String.to_integer(k))
        Server.spawnThreadsServer(0, 10000, zeroes, server_ip, k)
      end
  end
  
  #This function finds the server's IP address to make a connection"  
  def findIP do
    {ops_sys, versionof } = :os.type
    ip = 
    case ops_sys do
     :unix -> 
        case versionof do
          :darwin -> {:ok, [addr: ip]} = :inet.ifget('en0', [:addr])
          to_string(:inet.ntoa(ip)) 
          :linux ->  {:ok, [addr: ip]} = :inet.ifget('ens3', [:addr])
          to_string(:inet.ntoa(ip))
        end 
      :win32 -> {:ok, [ip, _]} = :inet.getiflist
        to_string(ip)
    end
      (ip)
  end
end

#This is the Worker module which consists of the functions of the worker 
defmodule Worker do
  #The worker is initialized, cookie is set for connection and then it is connected to the server"
  def initialize_worker(server_ip) do
    Node.start(:client)
    Node.set_cookie :'chocolate'
    connection = Node.connect(server_ip)
    if Atom.to_string(connection) === "true" do
      IO.puts "Connected to the master successfully!"
    else
      raise "Connection failed!"
    end  
  end
  
  #The worker calls the GenServer to get 'k' which is the required number of leading zeroes
  def get_zeroes(server_ip, k) do
    number_zeroes = GenServer.call({:gens, server_ip}, :msg)
    zeroes = String.duplicate("0",String.to_integer(number_zeroes))
    mine_bitcoin(zeroes, server_ip, k)
  end
  
  #The worker calls the function to spawn threads
  def mine_bitcoin(zeroes, server_ip, k) do
    try do
      Worker.spawnThreadsClient(0, 10000, zeroes, server_ip, k)
    catch
      :exit,_ -> IO.puts "Server died!"; exit(:shutdown)
      :break
    end
  end
  
  #The worker spawns threads and calls the function to mine bitcoins
  def spawnThreadsClient(count, intx, zeroes, server_ip, k) do
    if count === intx do
      raise "Maximum number of threads reached!"
      :break
    else     
      random_str = GenServer.call({:gens,server_ip}, :get_str)
      spawn(Hashing,:bitcoinHashing, [random_str, 0, zeroes, server_ip, k])
      spawnThreadsClient(count+1, intx, zeroes, server_ip, k)
      end 
  end

  #The worker sends the mined bitcoin to the GenServer
  def send_hash(:gens, hash, server_ip) do
    GenServer.cast({:gens, server_ip}, {:send_hash, hash})
  end
end

#This module contains our hashing function to mine bitcoins. 
#Here, we have done a sha256 of the appended UFID and a random string which we have generated in our random function.
#The worker then sends the hash to the handle_cast so that the server can print it.
 defmodule Hashing do
  def bitcoinHashing(random_str, counter, zeroes, server_ip, k) 
     do
         final_str = random_str <> Integer.to_string(counter)
         hash = String.downcase(:crypto.hash(:sha256, final_str )|> Base.encode16)

         if String.starts_with?(hash,zeroes)
             do bitcoin = final_str <> "\t" <> hash 
                if String.match?(k, ~r/[\d]+\.[\d]+\.[\d]+\.[\d]+/)
                do
                   Worker.send_hash(:gens,bitcoin,server_ip)
                else
                  IO.puts bitcoin
                end
         end
         bitcoinHashing(random_str, counter+1, zeroes,server_ip, k)
     end 
  end


#Module for creating random strings from alphabets and digits for distribution of work to the workers from the servers so that the random string can never be the same and then we append the integer values
defmodule RandomizeStrings do
   def randomizer(length, type \\ :all) do
     alphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
     numbers = "0123456789"

      lists =
       cond do
         type == :alpha -> alphabets <> String.downcase(alphabets)
         type == :numeric -> numbers
         type == :upcase -> alphabets
         type == :downcase -> String.downcase(alphabets)
         true -> alphabets <> String.downcase(alphabets) <> numbers
       end
       |> String.split("", trim: true)

     do_randomizer(length, lists)
   end

  defp get_range(length) when length > 1, do: (1..length)
  defp get_range(length), do: [1]

  defp do_randomizer(length, lists) do
     get_range(length)
     |> Enum.reduce([], fn(_, acc) -> [Enum.random(lists) | acc] end)
     |> Enum.join("")
  end
 end