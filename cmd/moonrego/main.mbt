///|
extern "c" fn moonrego_exit(code : Int32) -> Unit = "exit"

///|
async fn main {
  let all_arguments = @env.args()
  let arguments : Array[String] = []
  for index in 1..<all_arguments.length() {
    arguments.push(all_arguments[index])
  }
  let code = @cli.run(arguments)
  moonrego_exit(code)
}
