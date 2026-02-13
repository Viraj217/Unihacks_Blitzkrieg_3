import supabase from "../config/supabase.js";

async function UserSignup(req, res) {
    const cred = req.body;
    console.log(cred);

    const { data, error } = await supabase.auth.signUp({
        email: cred.email,
        password: cred.password,
    });

    if (error) return res.status(400).json({ error: error.message });
    res.json(data);
};

async function UserLogin(req, res) {
    const cred = req.body;

    const { data, error } = await supabase.auth.signInWithPassword({
        email: cred.email,
        password: cred.password,
    });

    if (error) return res.status(400).json({ error: error.message });

    res.json(data);
};

export { UserSignup, UserLogin };