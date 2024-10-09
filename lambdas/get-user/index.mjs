export const getUser = async (event) => {
    console.log('hello from getUser', event);
    return {
        statusCode: 200,
        headers: {
            "Access-Control-Allow-Origin": "*" 
        },
        body: "Hello from getUser"
    }
}