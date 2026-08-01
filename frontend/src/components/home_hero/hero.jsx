import { useContext } from 'react';
import { AuthContext } from '../../contexts/auth.context';
import './hero.css'
import {Link} from 'react-router-dom'

function Hero() {
    
    const {user, toggleUser} = useContext(AuthContext)

    return(
        <section className="hero-section" id='hero'>
            <h1>Welcome to AWS EKS ecommerce application.</h1>

            <h3>We believe it's based on AWS EKS with behind the alb , ingress and helm. We aim to learn and understand the kubernetes briefly.</h3>
            <div>
                <Link to='/products/All'><button>Shop now</button></Link>
                
            </div>
        </section>
    )
}



export default Hero;