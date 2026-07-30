
public class IMC {
	public String classificaIMC(float peso, float altura){
		float imc = peso / (altura*altura);
		if(imc<18.5){
			return "Abaixo do peso";
		}else if(imc <= 24.9){
			return "Peso normal";
		}else if(imc<=29.9){
			return "Pré obesidade";
		}else if(imc<=34.9){
			return "Obesidade";
		}else{
			return "Obesidade morbida";
		}
	}
}

